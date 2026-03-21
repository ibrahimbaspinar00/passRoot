import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../services/vault_crypto_background_service.dart';
import '../services/vault_crypto_service.dart';
import '../services/vault_file_service.dart';
import '../state/app_settings_store.dart';
import '../state/vault_store.dart';
import '../utils/app_logger.dart';
import '../widgets/pin_dialogs.dart';
import '../widgets/settings_section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.settingsStore,
  });

  final VaultStore store;
  final AppSettingsStore settingsStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _encryptedBackupFormat = 'passroot-encrypted-backup-v1';

  late final VaultCryptoBackgroundService _cryptoWorker;
  PackageInfo? _packageInfo;
  bool _ioBusy = false;
  String? _ioStatus;
  String? _lastImportPath;

  @override
  void initState() {
    super.initState();
    _cryptoWorker = const VaultCryptoBackgroundService();
    widget.settingsStore.refreshPinAvailability();
    _loadPackageInfo();
    _loadImportPreferences();
  }

  Future<void> _loadPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } on Exception catch (error, stackTrace) {
      AppLogger.debug(
        'SettingsScreen',
        'PackageInfo could not be loaded',
        error: error,
        stackTrace: stackTrace,
      );
      _packageInfo = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadImportPreferences() async {
    final path = await VaultFileService.lastImportPath();
    if (!mounted) return;
    setState(() {
      _lastImportPath = path;
    });
  }

  String get _appVersion {
    final info = _packageInfo;
    if (info == null) {
      return context.tr('YÃ¼kleniyor...', 'Loading...');
    }
    return '${info.version} (${info.buildNumber})';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String okText,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Ä°ptal', 'Cancel')),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(okText),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<bool> _confirmPlaintextImportRisk(String fileTypeLabel) async {
    final first = await _confirm(
      title: context.tr('Duz Metin Icerik Riski', 'Plaintext Data Risk'),
      body: context.tr(
        '$fileTypeLabel dosyalari sifrelenmemis olabilir. Bu dosya ele gecerse tum kayitlariniz okunabilir.',
        '$fileTypeLabel files may be unencrypted. If leaked, all records can be read.',
      ),
      okText: context.tr('Riski Anladim', 'I Understand the Risk'),
      danger: true,
    );
    if (!first) {
      return false;
    }
    if (!mounted) {
      return false;
    }
    final second = await _confirm(
      title: context.tr('Son Onay', 'Final Confirmation'),
      body: context.tr(
        'Bu import guvenli varsayilan akisin disindadir. Sadece guvenilir kaynaktan gelen dosyalarla devam edin.',
        'This import is outside the secure default flow. Continue only with trusted files.',
      ),
      okText: context.tr('Yine de Devam Et', 'Continue Anyway'),
      danger: true,
    );
    return second;
  }

  void _setIoStatus(String? next) {
    if (!mounted) return;
    setState(() {
      _ioStatus = next;
    });
  }

  Future<void> _setBusy(
    Future<void> Function() action, {
    String? initialStatus,
  }) async {
    if (_ioBusy) return;
    setState(() {
      _ioBusy = true;
      _ioStatus = initialStatus;
    });
    try {
      await action();
    } on VaultStoreException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } on VaultCryptoException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } on Exception catch (error, stackTrace) {
      AppLogger.debug(
        'SettingsScreen',
        'Unexpected IO flow error',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _snack(
        context.tr(
          'Ä°ÅŸlem tamamlanamadÄ±. LÃ¼tfen tekrar deneyin.',
          'Operation failed. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _ioBusy = false;
          _ioStatus = null;
        });
      }
    }
  }

  String _stamp(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  String _shortPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return '';
    if (normalized.length <= 56) {
      return normalized;
    }
    final file = p.basename(normalized);
    final tail = normalized.substring(normalized.length - 24);
    return '$file ...$tail';
  }

  Future<String?> _askEncryptionKey({
    required String title,
    required String actionText,
    required bool requireConfirmation,
  }) async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    var hiddenMain = true;
    var hiddenConfirm = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(
                      'Bu anahtar yedek dosyasini sifrelemek/cozmek icin kullanilir. Unutursaniz yedek acilamaz.',
                      'This key encrypts/decrypts the backup file. If forgotten, backup cannot be opened.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passController,
                    obscureText: hiddenMain,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'Sifreleme Anahtari',
                        'Encryption Key',
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            hiddenMain = !hiddenMain;
                          });
                        },
                        icon: Icon(
                          hiddenMain
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  if (requireConfirmation) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      obscureText: hiddenConfirm,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          'Anahtari Tekrar Girin',
                          'Repeat Key',
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              hiddenConfirm = !hiddenConfirm;
                            });
                          },
                          icon: Icon(
                            hiddenConfirm
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Ä°ptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final pass = passController.text.trim();
                    final repeated = confirmController.text.trim();
                    if (pass.length < 8) {
                      setDialogState(() {
                        errorText = context.tr(
                          'Anahtar en az 8 karakter olmali.',
                          'Key must be at least 8 characters.',
                        );
                      });
                      return;
                    }
                    if (requireConfirmation && pass != repeated) {
                      setDialogState(() {
                        errorText = context.tr(
                          'Anahtarlar eslesmiyor.',
                          'Keys do not match.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, pass);
                  },
                  child: Text(actionText),
                ),
              ],
            );
          },
        );
      },
    );

    passController.dispose();
    confirmController.dispose();
    return result;
  }

  String _buildEncryptedEnvelope(String encryptedPayload) {
    return jsonEncode(<String, dynamic>{
      'format': _encryptedBackupFormat,
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'payload': encryptedPayload,
    });
  }

  String? _extractEncryptedPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final format = (decoded['format'] as String?)?.trim();
      if (format != _encryptedBackupFormat) return null;
      final payload = (decoded['payload'] as String?)?.trim();
      if (payload == null || payload.isEmpty) return null;
      return payload;
    } on FormatException {
      return null;
    }
  }

  bool _isPlainJsonVaultPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> && decoded['records'] is List;
    } on FormatException {
      return false;
    }
  }

  Future<int> _importFromContent({
    required String content,
    required bool allowPlainJson,
  }) async {
    final encryptedPayload = _extractEncryptedPayload(content);
    if (encryptedPayload != null) {
      _setIoStatus(
        context.tr(
          'Sifreli yedek icin anahtar bekleniyor...',
          'Waiting for backup key...',
        ),
      );
      final key = await _askEncryptionKey(
        title: context.tr('Yedek Anahtarini Girin', 'Enter Backup Key'),
        actionText: context.tr('Yedegi Ac', 'Decrypt Backup'),
        requireConfirmation: false,
      );
      if (key == null) {
        throw const FormatException('Islem iptal edildi.');
      }
      if (!mounted) {
        throw const FormatException('Islem iptal edildi.');
      }
      _setIoStatus(
        context.tr('Yedek dosyasi cozuluyor...', 'Decrypting backup...'),
      );
      final decrypted = await _cryptoWorker.decryptString(
        encryptedPayload: encryptedPayload,
        passphrase: key,
      );
      if (!mounted) {
        throw const FormatException('Islem iptal edildi.');
      }
      _setIoStatus(
        context.tr('Kayitlar ice aktariliyor...', 'Importing records...'),
      );
      return await widget.store.importFromJsonString(decrypted);
    }

    if (!allowPlainJson) {
      throw const FormatException(
        'Bu ekran yalnizca sifreli (.pvault) yedekleri kabul eder.',
      );
    }

    if (!_isPlainJsonVaultPayload(content)) {
      throw const FormatException('Dosya formati gecersiz veya bozuk.');
    }
    final proceed = await _confirmPlaintextImportRisk('JSON');
    if (!proceed) {
      throw const FormatException('Islem iptal edildi.');
    }
    if (!mounted) {
      throw const FormatException('Islem iptal edildi.');
    }
    _setIoStatus(
      context.tr(
        'JSON kayitlari ice aktariliyor...',
        'Importing JSON records...',
      ),
    );
    return await widget.store.importFromJsonString(content);
  }

  Future<void> _exportData() async {
    await _setBusy(() async {
      _setIoStatus(
        context.tr(
          'Sifreleme anahtari bekleniyor...',
          'Waiting for encryption key...',
        ),
      );
      final key = await _askEncryptionKey(
        title: context.tr('Sifreli Disa Aktar', 'Encrypted Export'),
        actionText: context.tr('Disa Aktar', 'Export'),
        requireConfirmation: true,
      );
      if (key == null) return;
      if (!mounted) return;

      _setIoStatus(
        context.tr(
          'Veriler export icin hazirlaniyor...',
          'Preparing export payload...',
        ),
      );
      final plainPayload = await widget.store.encodeJsonInBackground(
        pretty: false,
      );
      if (!mounted) return;
      _setIoStatus(
        context.tr('Veriler sifreleniyor...', 'Encrypting records...'),
      );
      final encryptedPayload = await _cryptoWorker.encryptString(
        plaintext: plainPayload,
        passphrase: key,
      );
      final fileName =
          'passroot_export_${DateTime.now().toIso8601String().split('T').first}.pvault';
      final selectedPath = await VaultFileService.pickExportFilePath(
        fileName: fileName,
        allowedExtensions: const <String>['pvault'],
      );
      if (!mounted) return;
      _setIoStatus(context.tr('Dosya kaydediliyor...', 'Saving file...'));
      final file = await VaultFileService.writeExportFile(
        content: _buildEncryptedEnvelope(encryptedPayload),
        path: selectedPath,
      );
      if (!mounted) return;
      _snack(
        context.tr(
          'Sifreli disa aktarma tamamlandi: ${file.path}',
          'Encrypted export completed: ${file.path}',
        ),
      );
    }, initialStatus: context.tr('Export baslatiliyor...', 'Starting export...'));
  }

  Future<void> _backupNow() async {
    await _setBusy(
      () async {
        _setIoStatus(
          context.tr(
            'Sifreleme anahtari bekleniyor...',
            'Waiting for encryption key...',
          ),
        );
        final key = await _askEncryptionKey(
          title: context.tr('Sifreli Yedek Olustur', 'Create Encrypted Backup'),
          actionText: context.tr('Yedekle', 'Backup'),
          requireConfirmation: true,
        );
        if (key == null) return;
        if (!mounted) return;

        _setIoStatus(
          context.tr(
            'Yedek icerigi hazirlaniyor...',
            'Preparing backup payload...',
          ),
        );
        final plainPayload = await widget.store.encodeJsonInBackground(
          pretty: false,
        );
        if (!mounted) return;
        _setIoStatus(
          context.tr('Yedek sifreleniyor...', 'Encrypting backup...'),
        );
        final encryptedPayload = await _cryptoWorker.encryptString(
          plaintext: plainPayload,
          passphrase: key,
        );
        if (!mounted) return;
        _setIoStatus(
          context.tr('Yedek dosyasi yaziliyor...', 'Writing backup file...'),
        );
        final file = await VaultFileService.createBackup(
          _buildEncryptedEnvelope(encryptedPayload),
          extension: 'pvault',
        );
        await widget.settingsStore.setLastBackupNow();
        if (!mounted) return;
        _snack(
          context.tr(
            'Sifreli yedek olusturuldu: ${file.path}',
            'Encrypted backup created: ${file.path}',
          ),
        );
      },
      initialStatus: context.tr('Yedek baslatiliyor...', 'Starting backup...'),
    );
  }

  Future<void> _importFromFilePath(
    String path, {
    required bool allowPlaintextFlow,
  }) async {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return;
    final fileExists = await VaultFileService.exists(cleanPath);
    if (!fileExists) {
      if (!mounted) return;
      _snack(
        context.tr(
          'Dosya bulunamadi. Lutfen tekrar secin.',
          'File not found. Please select again.',
        ),
      );
      await VaultFileService.clearLastImportPath();
      if (mounted) {
        setState(() {
          _lastImportPath = null;
        });
      }
      return;
    }

    if (!mounted) return;
    final confirm = await _confirm(
      title: context.tr('Verileri Ice Aktar', 'Import Data'),
      body: context.tr(
        'Bu islem mevcut kayitlari secilen dosyayla degistirecek.',
        'This will replace current records with selected file content.',
      ),
      okText: context.tr('Ice Aktar', 'Import'),
      danger: true,
    );
    if (!confirm) return;
    if (!mounted) return;

    _setIoStatus(context.tr('Dosya okunuyor...', 'Reading file...'));
    final content = await VaultFileService.readFile(cleanPath);
    final extension = p.extension(cleanPath).toLowerCase();

    final int count;
    if (extension == '.csv') {
      if (!allowPlaintextFlow) {
        throw const FormatException(
          'CSV import varsayilan olarak kapali. Gelismis/Riskli importu kullanin.',
        );
      }
      final proceed = await _confirmPlaintextImportRisk('CSV');
      if (!proceed) return;
      if (!mounted) return;
      _setIoStatus(
        context.tr('CSV kayitlari ayrisiyor...', 'Parsing CSV records...'),
      );
      count = await widget.store.importFromCsvString(content);
    } else {
      if (extension == '.json' && !allowPlaintextFlow) {
        throw const FormatException(
          'JSON import varsayilan olarak kapali. Gelismis/Riskli importu kullanin.',
        );
      }
      count = await _importFromContent(
        content: content,
        allowPlainJson: allowPlaintextFlow && extension == '.json',
      );
    }

    await VaultFileService.saveLastImportPath(cleanPath);
    if (!mounted) return;
    setState(() {
      _lastImportPath = cleanPath;
    });
    _snack(
      context.tr(
        '$count kayit basariyla ice aktarildi.',
        '$count records imported successfully.',
      ),
    );
  }

  Future<void> _importData() async {
    await _setBusy(
      () async {
        final initialDirectory = _lastImportPath == null
            ? null
            : p.dirname(_lastImportPath!);
        final path = await VaultFileService.pickImportFilePath(
          allowedExtensions: const <String>['pvault'],
          initialDirectory: initialDirectory,
        );
        if (path == null) return;
        await _importFromFilePath(path, allowPlaintextFlow: false);
      },
      initialStatus: context.tr('Import baslatiliyor...', 'Starting import...'),
    );
  }

  Future<void> _importRiskyPlaintextData() async {
    await _setBusy(
      () async {
        final initialDirectory = _lastImportPath == null
            ? null
            : p.dirname(_lastImportPath!);
        final path = await VaultFileService.pickImportFilePath(
          allowedExtensions: const <String>['json', 'csv'],
          initialDirectory: initialDirectory,
        );
        if (path == null) return;
        await _importFromFilePath(path, allowPlaintextFlow: true);
      },
      initialStatus: context.tr(
        'Riskli import baslatiliyor...',
        'Starting risky import...',
      ),
    );
  }

  Future<void> _importFromLastSelectedPath() async {
    final path = (_lastImportPath ?? '').trim();
    if (path.isEmpty) {
      _snack(
        context.tr(
          'Son secilen import dosyasi bulunamadi.',
          'No recently selected import file found.',
        ),
      );
      return;
    }
    await _setBusy(
      () async {
        await _importFromFilePath(path, allowPlaintextFlow: false);
      },
      initialStatus: context.tr('Import baslatiliyor...', 'Starting import...'),
    );
  }

  Future<void> _restoreBackup() async {
    await _setBusy(() async {
      final backups = await VaultFileService.listBackups();
      if (!mounted) return;
      if (backups.isEmpty) {
        _snack(
          context.tr(
            'Geri yuklenecek yedek bulunamadi.',
            'No backup found to restore.',
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<File>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final file in backups)
                  ListTile(
                    leading: const Icon(Icons.backup_rounded),
                    title: Text(file.uri.pathSegments.last),
                    subtitle: Text(_stamp(file.statSync().modified)),
                    onTap: () => Navigator.pop(context, file),
                  ),
              ],
            ),
          );
        },
      );
      if (selected == null) return;

      if (!mounted) return;
      final confirm = await _confirm(
        title: context.tr('Yedekten Geri Yukle', 'Restore Backup'),
        body: context.tr(
          'Secilen yedek yuklendiginde mevcut kayitlar degisecek.',
          'Current records will be replaced with selected backup.',
        ),
        okText: context.tr('Geri Yukle', 'Restore'),
        danger: true,
      );
      if (!confirm) return;
      if (!mounted) return;

      _setIoStatus(
        context.tr('Yedek dosyasi okunuyor...', 'Reading backup file...'),
      );
      final content = await selected.readAsString();
      if (!mounted) return;
      _setIoStatus(
        context.tr(
          'Yedek icerigi yukleniyor...',
          'Importing backup content...',
        ),
      );
      final count = await _importFromContent(
        content: content,
        allowPlainJson: selected.path.toLowerCase().endsWith('.json'),
      );
      if (!mounted) return;
      _snack(
        context.tr('$count kayit geri yuklendi.', '$count records restored.'),
      );
    });
  }

  Future<void> _clearAllRecords() async {
    final confirm = await _confirm(
      title: context.tr('TÃ¼m Veriler Silinsin mi?', 'Delete All Data?'),
      body: context.tr(
        'Bu iÅŸlem geri alÄ±namaz. TÃ¼m kasa kayÄ±tlarÄ± silinecek.',
        'This action cannot be undone. All vault records will be deleted.',
      ),
      okText: context.tr('Sil', 'Delete'),
      danger: true,
    );
    if (!confirm) return;

    await _setBusy(() async {
      await widget.store.clearAllRecords();
      if (!mounted) return;
      _snack(
        context.tr('TÃ¼m kayÄ±tlar silindi.', 'All records have been deleted.'),
      );
    });
  }

  Future<bool> _managePin() async {
    await widget.settingsStore.refreshPinAvailability(notify: false);
    if (!mounted) return false;
    final hasPin = widget.settingsStore.pinAvailable;
    if (!hasPin) {
      final newPin = await PinDialogs.askNewPin(
        context,
        title: context.tr('Giris PIN\'i Olustur', 'Create Access PIN'),
        description: context.tr(
          'Uygulamaya giris icin kullanacaginiz PIN kodunu belirleyin.',
          'Set the PIN you will use to sign in to the app.',
        ),
      );
      if (newPin == null) return false;
      await widget.settingsStore.setPinCode(newPin);
      if (!mounted) return false;
      _snack(
        context.tr(
          'Giris PIN\'i ayarlandi.',
          'Access PIN has been configured.',
        ),
      );
      return true;
    }

    final verified = await PinDialogs.verifyPin(
      context: context,
      onVerify: widget.settingsStore.verifyPinDetailed,
      title: context.tr('Mevcut PIN Dogrulama', 'Verify Current PIN'),
      description: context.tr(
        'PIN degistirmek icin mevcut PIN kodunuzu girin.',
        'Enter current PIN to change it.',
      ),
    );
    if (!mounted || !verified) return false;

    final newPin = await PinDialogs.askNewPin(
      context,
      title: context.tr('Yeni Giris PIN\'i', 'New Access PIN'),
      description: context.tr(
        'Yeni PIN 4-8 rakam olmali ve kolay tahmin edilmemeli.',
        'New PIN must be 4-8 digits and not easy to guess.',
      ),
      actionText: context.tr('PIN\'i Guncelle', 'Update PIN'),
    );
    if (newPin == null) return false;
    await widget.settingsStore.setPinCode(newPin);
    if (!mounted) return false;
    _snack(
      context.tr('Giris PIN\'i guncellendi.', 'Access PIN has been updated.'),
    );
    return true;
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      await widget.settingsStore.refreshPinAvailability(notify: false);
      if (!mounted) return;
      if (!widget.settingsStore.pinAvailable) {
        _snack(
          context.tr(
            'Uygulama kilidi iÃ§in Ã¶nce bir PIN oluÅŸturun.',
            'Create an access PIN before enabling app lock.',
          ),
        );
        final created = await _managePin();
        if (!created) return;
      }
    }

    await widget.settingsStore.setAppLockEnabled(enabled);
    if (!mounted) return;
    _snack(
      enabled
          ? context.tr('Uygulama kilidi aktif edildi.', 'App lock enabled.')
          : context.tr('Uygulama kilidi kapatÄ±ldÄ±.', 'App lock disabled.'),
    );
  }

  Future<void> _pickThemeAccent() async {
    final selected = await showModalBottomSheet<AppThemeAccent>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = widget.settingsStore.settings.themeAccent;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final accent in AppThemeAccent.values)
                ListTile(
                  leading: Icon(
                    current == accent
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: accent.seedColor,
                  ),
                  title: Text(accent.localizedLabel(context)),
                  onTap: () => Navigator.pop(context, accent),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await widget.settingsStore.setThemeAccent(selected);
    }
  }

  Future<void> _pickCardStyle() async {
    final selected = await showModalBottomSheet<RecordCardStyle>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = widget.settingsStore.settings.cardStyle;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final style in RecordCardStyle.values)
                ListTile(
                  leading: Icon(
                    current == style
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                  ),
                  title: Text(style.localizedLabel(context)),
                  onTap: () => Navigator.pop(context, style),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await widget.settingsStore.setRecordCardStyle(selected);
    }
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = widget.settingsStore.settings.language;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final language in AppLanguage.values)
                ListTile(
                  leading: Icon(
                    current == language
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                  ),
                  title: Text(language.localizedLabel(context)),
                  onTap: () => Navigator.pop(context, language),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await widget.settingsStore.setLanguage(selected);
    }
  }

  Future<void> _pickAutoLockOption() async {
    final selected = await showModalBottomSheet<AutoLockOption>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = widget.settingsStore.settings.autoLockOption;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final option in AutoLockOption.values)
                ListTile(
                  leading: Icon(
                    current == option
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                  ),
                  title: Text(option.localizedLabel(context)),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await widget.settingsStore.setAutoLockOption(selected);
      if (!mounted) return;
      _snack(
        context.tr(
          'Otomatik kilit sÃ¼resi gÃ¼ncellendi.',
          'Auto lock duration updated.',
        ),
      );
    }
  }

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'PassRoot Vault',
      applicationVersion: _appVersion,
      applicationIcon: const Icon(Icons.lock_person_rounded),
      children: [
        Text(
          context.tr(
            'PassRoot, hassas kayitlarinizi cihazinizda sifreli olarak yonetmek icin tasarlanmistir.',
            'PassRoot is designed for managing sensitive records with encrypted local storage.',
          ),
        ),
      ],
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _StaticContentPage(
          title: context.tr('Gizlilik Politikasi', 'Privacy Policy'),
          body: context.tr(
            'Kasa verileri cihazda sifreli saklanir. Disa aktarma ve yedekleme dosyalarinin guvenliginden kullanici sorumludur.',
            'Vault data is encrypted on device. User is responsible for securing exported and backup files.',
          ),
        ),
      ),
    );
  }

  void _openHelpSupport() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _StaticContentPage(
          title: context.tr('Yardim / Destek', 'Help / Support'),
          body: context.tr(
            'Destek: support@passroot.app\n\nOneri: Duzenli sifreli yedek alin ve anahtarinizi guvenli bir yerde saklayin.',
            'Support: support@passroot.app\n\nTip: Take encrypted backups regularly and keep your key in a safe place.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, widget.settingsStore]),
      builder: (context, _) {
        final settings = widget.settingsStore.settings;
        final strongCount = widget.store.strongRecords.length;
        final weakCount = widget.store.weakRecords.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            if (_ioBusy && (_ioStatus ?? '').trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.pr.panelSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.pr.panelBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ioStatus!,
                      style: TextStyle(
                        color: context.pr.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SettingsSectionCard(
              title: context.tr('GÃ¼venlik', 'Security'),
              children: [
                _switchTile(
                  icon: Icons.lock_outline_rounded,
                  title: context.tr('Uygulama Kilidi', 'App Lock'),
                  subtitle: context.tr(
                    settings.appLockEnabled
                        ? 'AÃ§Ä±lÄ±ÅŸta PIN doÄŸrulamasÄ± aktif. PIN olmadan kasa aÃ§Ä±lamaz.'
                        : 'KapalÄ±ysa aÃ§Ä±lÄ±ÅŸta PIN sorulmaz (gÃ¼venlik Ã¶nerilmez).',
                    settings.appLockEnabled
                        ? 'PIN verification on launch is active.'
                        : 'If disabled, app starts without PIN prompt.',
                  ),
                  value: settings.appLockEnabled,
                  onChanged: _toggleAppLock,
                ),
                if (settings.appLockEnabled) ...[
                  const SizedBox(height: 8),
                  _switchTile(
                    icon: Icons.rocket_launch_outlined,
                    title: context.tr(
                      'AÃ§Ä±lÄ±ÅŸta Kilidi Uygula',
                      'Enforce Lock on Launch',
                    ),
                    subtitle: context.tr(
                      'Uygulama her aÃ§Ä±lÄ±ÅŸta PIN ister.',
                      'App starts locked on every launch.',
                    ),
                    value: settings.lockOnAppLaunch,
                    onChanged: widget.settingsStore.setLockOnAppLaunch,
                  ),
                  const SizedBox(height: 8),
                  _switchTile(
                    icon: Icons.lock_clock_outlined,
                    title: context.tr(
                      'Arka Plandan DÃ¶nÃ¼ÅŸte Kilitle',
                      'Lock on Resume',
                    ),
                    subtitle: context.tr(
                      'Arka plandan dÃ¶nÃ¼nce, seÃ§ilen sÃ¼re aÅŸÄ±ldÄ±ysa tekrar PIN ister.',
                      'Re-locks after returning from background based on timeout.',
                    ),
                    value: settings.lockOnAppResume,
                    onChanged: widget.settingsStore.setLockOnAppResume,
                  ),
                  const SizedBox(height: 8),
                  _actionTile(
                    icon: Icons.schedule_rounded,
                    title: context.tr(
                      'Otomatik Kilit SÃ¼resi',
                      'Auto Lock Delay',
                    ),
                    subtitle: context.tr(
                      'SeÃ§ili: ${settings.autoLockOption.localizedLabel(context)}',
                      'Selected: ${settings.autoLockOption.localizedLabel(context)}',
                    ),
                    onTap: _pickAutoLockOption,
                  ),
                ],
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.pin_outlined,
                  title: context.tr(
                    widget.settingsStore.pinAvailable
                        ? 'Uygulama PIN\'ini DeÄŸiÅŸtir'
                        : 'Uygulama PIN\'i OluÅŸtur',
                    widget.settingsStore.pinAvailable
                        ? 'Change App PIN'
                        : 'Create App PIN',
                  ),
                  subtitle: widget.settingsStore.pinAvailable
                      ? context.tr(
                          'PIN korumasÄ± aktif. GÃ¼venliÄŸi dÃ¼zenli gÃ¼ncelleyin.',
                          'PIN protection is active. Update it regularly.',
                        )
                      : context.tr(
                          'Uygulama kilidi iÃ§in Ã¶nce PIN tanÄ±mlayÄ±n.',
                          'Set a PIN before enabling app lock.',
                        ),
                  onTap: _managePin,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Gorunum', 'Appearance'),
              children: [
                _switchTile(
                  icon: Icons.dark_mode_outlined,
                  title: context.tr('Koyu Tema', 'Dark Theme'),
                  subtitle: context.tr(
                    'Acik/koyu tema gecisi',
                    'Switch light/dark theme',
                  ),
                  value: settings.darkMode,
                  onChanged: widget.settingsStore.setDarkMode,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.color_lens_outlined,
                  title: context.tr('Tema Vurgu Rengi', 'Theme Accent'),
                  subtitle: settings.themeAccent.localizedLabel(context),
                  onTap: _pickThemeAccent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Veri Yonetimi', 'Data Management'),
              children: [
                _actionTile(
                  icon: Icons.backup_rounded,
                  title: context.tr(
                    'Sifreli Yedek Olustur',
                    'Create Encrypted Backup',
                  ),
                  subtitle: settings.lastBackupAt == null
                      ? context.tr('Henuz yedek yok', 'No backup yet')
                      : context.tr(
                          'Son yedek: ${_stamp(settings.lastBackupAt!)}',
                          'Last backup: ${_stamp(settings.lastBackupAt!)}',
                        ),
                  onTap: _ioBusy ? null : _backupNow,
                  loading: _ioBusy,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.restore_rounded,
                  title: context.tr('Yedekten Geri Yukle', 'Restore Backup'),
                  subtitle: context.tr(
                    'Sifreli veya eski yedek dosyasini geri yukle',
                    'Restore encrypted or legacy backup file',
                  ),
                  onTap: _ioBusy ? null : _restoreBackup,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.file_upload_rounded,
                  title: context.tr('Sifreli Disa Aktar', 'Encrypted Export'),
                  subtitle: context.tr(
                    'Verileri sifreli dosya olarak disa aktar',
                    'Export records as encrypted file',
                  ),
                  onTap: _ioBusy ? null : _exportData,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.file_download_rounded,
                  title: context.tr('Dosyadan Ice Aktar', 'Import from File'),
                  subtitle: context.tr(
                    'Guvenli varsayilan: yalnizca sifreli .pvault dosyasi',
                    'Secure default: encrypted .pvault file only',
                  ),
                  onTap: _ioBusy ? null : _importData,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.warning_amber_rounded,
                  title: context.tr(
                    'Gelismis: Duz Metin Import (Riskli)',
                    'Advanced: Plaintext Import (Risky)',
                  ),
                  subtitle: context.tr(
                    'JSON/CSV icin cift onay gerekir. Yalnizca guvenilir dosyalarda kullanin.',
                    'Requires double confirmation for JSON/CSV. Use only for trusted files.',
                  ),
                  danger: true,
                  onTap: _ioBusy ? null : _importRiskyPlaintextData,
                ),
                if ((_lastImportPath ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _actionTile(
                    icon: Icons.history_rounded,
                    title: context.tr(
                      'Son Dosyadan Tekrar Aktar',
                      'Import from Last File',
                    ),
                    subtitle: _shortPath(_lastImportPath!),
                    onTap: _ioBusy ? null : _importFromLastSelectedPath,
                  ),
                ],
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.delete_forever_rounded,
                  title: context.tr('TÃ¼m Verileri Sil', 'Delete All Data'),
                  subtitle: context.tr(
                    'Geri alÄ±namaz bir iÅŸlemdir',
                    'This action is irreversible',
                  ),
                  danger: true,
                  onTap: _ioBusy ? null : _clearAllRecords,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Uygulama Tercihleri', 'App Preferences'),
              children: [
                _actionTile(
                  icon: Icons.view_compact_alt_outlined,
                  title: context.tr('Kasa Kart Gorunumu', 'Vault Card Style'),
                  subtitle: settings.cardStyle.localizedLabel(context),
                  onTap: _pickCardStyle,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.language_rounded,
                  title: context.tr('Dil', 'Language'),
                  subtitle: settings.language.localizedLabel(context),
                  onTap: _pickLanguage,
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  context.tr('Toplam Kayit', 'Total Records'),
                  '${widget.store.totalCount}',
                ),
                _summaryRow(
                  context.tr('Parola Durumu', 'Password Summary'),
                  context.tr(
                    '$strongCount guclu / $weakCount zayif',
                    '$strongCount strong / $weakCount weak',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Hakkinda', 'About'),
              children: [
                _actionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: context.tr('Gizlilik Politikasi', 'Privacy Policy'),
                  subtitle: context.tr(
                    'Veri kullanimi ve guvenlik',
                    'Data use and security',
                  ),
                  onTap: _openPrivacyPolicy,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.support_agent_rounded,
                  title: context.tr('Yardim / Destek', 'Help / Support'),
                  subtitle: context.tr('Destek bilgileri', 'Support details'),
                  onTap: _openHelpSupport,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.info_outline_rounded,
                  title: context.tr('Surum Bilgisi', 'Version'),
                  subtitle: _appVersion,
                  onTap: _openAbout,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    final pr = context.pr;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: pr.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final pr = context.pr;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: pr.softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pr.panelBorder),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        secondary: Icon(icon),
        title: Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        onChanged: onChanged,
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool loading = false,
    bool danger = false,
  }) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: danger ? pr.dangerSoft : pr.softFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: danger
                ? scheme.error.withValues(alpha: 0.28)
                : pr.panelBorder,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: danger ? scheme.error : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: danger ? scheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: pr.textMuted),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _StaticContentPage extends StatelessWidget {
  const _StaticContentPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
