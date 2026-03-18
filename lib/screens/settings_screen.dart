import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../services/vault_file_service.dart';
import '../state/app_settings_store.dart';
import '../state/vault_store.dart';
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
  PackageInfo? _packageInfo;
  bool _ioBusy = false;

  @override
  void initState() {
    super.initState();
    widget.settingsStore.refreshBiometricCapability();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _packageInfo = null;
    }
    if (mounted) setState(() {});
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _stamp(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  String get _appVersion {
    final info = _packageInfo;
    if (info == null) return context.tr('Yukleniyor...', 'Loading...');
    return '${info.version} (${info.buildNumber})';
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String okText,
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
              child: Text(context.tr('Iptal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(okText),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _setBusy(Future<void> Function() action) async {
    if (_ioBusy) return;
    setState(() {
      _ioBusy = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _snack(
          context.tr(
            'Islem sirasinda hata olustu: $error',
            'An error occurred: $error',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _ioBusy = false;
        });
      }
    }
  }

  Future<void> _pickAutoLock() async {
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
    }
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
                  leading: CircleAvatar(
                    radius: 11,
                    backgroundColor: accent.seedColor,
                    child: current == accent
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
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

  Future<void> _managePin() async {
    final currentPin = widget.settingsStore.settings.pinCode;
    if ((currentPin ?? '').isEmpty) {
      final newPin = await _askNewPin();
      if (newPin == null) return;
      await widget.settingsStore.setPinCode(newPin);
      if (!mounted) return;
      _snack(context.tr('PIN kodu ayarlandi.', 'PIN configured.'));
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: Text(context.tr('PIN Degistir', 'Change PIN')),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(context.tr('PIN Kaldir', 'Remove PIN')),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null) return;
    final expectedPin = currentPin ?? '';
    if (expectedPin.isEmpty) return;

    final verified = await _verifyPin(expectedPin);
    if (!mounted) return;
    if (!verified) {
      _snack(context.tr('PIN dogrulamasi basarisiz.', 'PIN verification failed.'));
      return;
    }
    if (action == 'remove') {
      await widget.settingsStore.clearPinCode();
      if (!mounted) return;
      _snack(context.tr('PIN kaldirildi.', 'PIN removed.'));
      return;
    }
    final newPin = await _askNewPin();
    if (newPin == null) return;
    await widget.settingsStore.setPinCode(newPin);
    if (!mounted) return;
    _snack(context.tr('PIN guncellendi.', 'PIN updated.'));
  }

  Future<String?> _askNewPin() async {
    final pinController = TextEditingController();
    final repeatController = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('PIN Kodu Ayarla', 'Set PIN')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Yeni PIN', 'New PIN'),
                      errorText: errorText,
                    ),
                  ),
                  TextField(
                    controller: repeatController,
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.tr('PIN Tekrar', 'Repeat PIN'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
                      setDialogState(() {
                        errorText = context.tr(
                          'PIN 4-8 rakam olmali.',
                          'PIN must be 4-8 digits.',
                        );
                      });
                      return;
                    }
                    if (pin != repeatController.text.trim()) {
                      setDialogState(() {
                        errorText = context.tr(
                          'PIN kodlari eslesmiyor.',
                          'PIN values do not match.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, pin);
                  },
                  child: Text(context.tr('Kaydet', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    repeatController.dispose();
    return result;
  }

  Future<bool> _verifyPin(String expected) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('PIN Dogrulama', 'Verify PIN')),
              content: TextField(
                controller: controller,
                maxLength: 8,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr('Mevcut PIN', 'Current PIN'),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim() == expected) {
                      Navigator.pop(context, true);
                      return;
                    }
                    setDialogState(() {
                      errorText = context.tr('PIN hatali.', 'Incorrect PIN.');
                    });
                  },
                  child: Text(context.tr('Dogrula', 'Verify')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result == true;
  }

  Future<void> _openNotificationSettings() async {
    var local = widget.settingsStore.settings.notifications;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile.adaptive(
                      value: local.weakPasswordAlert,
                      title: Text(
                        context.tr(
                          'Zayif sifre uyarilari',
                          'Weak password alerts',
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          local = local.copyWith(weakPasswordAlert: value);
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: local.reusedPasswordAlert,
                      title: Text(
                        context.tr(
                          'Tekrar eden sifre uyarilari',
                          'Reused password alerts',
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          local = local.copyWith(reusedPasswordAlert: value);
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: local.backupReminder,
                      title: Text(
                        context.tr(
                          'Yedekleme hatirlatmasi',
                          'Backup reminders',
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          local = local.copyWith(backupReminder: value);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.tr('Kaydet', 'Save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved == true) {
      await widget.settingsStore.setNotificationSettings(local);
      if (!mounted) return;
      _snack(
        context.tr(
          'Bildirim tercihleri guncellendi.',
          'Notification preferences updated.',
        ),
      );
    }
  }

  Future<void> _openPasswordGeneratorSettings() async {
    var local = widget.settingsStore.settings.passwordGenerator;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                context.tr(
                  'Sifre Uretici Ayarlari',
                  'Password Generator Settings',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(context.tr('Uzunluk', 'Length'))),
                        Text(
                          '${local.length}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Slider(
                      value: local.length.toDouble(),
                      min: 8,
                      max: 40,
                      divisions: 32,
                      label: '${local.length}',
                      onChanged: (value) {
                        setDialogState(() {
                          local = local.copyWith(length: value.round());
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: local.includeUppercase,
                      title: Text(context.tr('Buyuk harf', 'Uppercase letters')),
                      onChanged: (value) {
                        setDialogState(() {
                          local = local.copyWith(includeUppercase: value);
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: local.includeLowercase,
                      title: Text(context.tr('Kucuk harf', 'Lowercase letters')),
                      onChanged: (value) {
                        setDialogState(() {
                          local = local.copyWith(includeLowercase: value);
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: local.includeNumbers,
                      title: Text(context.tr('Rakam', 'Numbers')),
                      onChanged: (value) {
                        setDialogState(() {
                          local = local.copyWith(includeNumbers: value);
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: local.includeSymbols,
                      title: Text(context.tr('Sembol', 'Symbols')),
                      onChanged: (value) {
                        setDialogState(() {
                          local = local.copyWith(includeSymbols: value);
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.tr('Kaydet', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      await widget.settingsStore.setPasswordGeneratorSettings(local);
      if (!mounted) return;
      _snack(
        context.tr(
          'Sifre uretici ayarlari kaydedildi.',
          'Password generator settings saved.',
        ),
      );
    }
  }

  Future<void> _exportData() async {
    await _setBusy(() async {
      final exportName =
          'passroot_export_${DateTime.now().toIso8601String().split('T').first}.json';
      final selectedPath = await VaultFileService.pickExportFilePath(
        fileName: exportName,
      );
      final file = await VaultFileService.writeExportFile(
        content: widget.store.encodeJson(pretty: true),
        path: selectedPath,
      );
      if (!mounted) return;
      _snack(
        context.tr(
          'Veriler disa aktarildi: ${file.path}',
          'Data exported: ${file.path}',
        ),
      );
    });
  }

  Future<void> _importData() async {
    await _setBusy(() async {
      final path = await VaultFileService.pickImportFilePath();
      if (path == null) return;
      if (!mounted) return;
      final confirm = await _confirm(
        title: context.tr('Veriler Iceri Aktarilsin mi?', 'Import Data?'),
        body: context.tr(
          'Bu islem mevcut kayitlari secilen dosyayla degistirecek.',
          'This replaces current records with selected file content.',
        ),
        okText: context.tr('Iceri Aktar', 'Import'),
      );
      if (!confirm) return;
      final content = await VaultFileService.readFile(path);
      final count = widget.store.importFromJsonString(content);
      if (!mounted) return;
      _snack(context.tr('$count kayit ice aktarildi.', '$count records imported.'));
    });
  }

  Future<void> _backupNow() async {
    await _setBusy(() async {
      final file = await VaultFileService.createBackup(widget.store.encodeJson());
      await widget.settingsStore.setLastBackupNow();
      if (!mounted) return;
      _snack(
        context.tr(
          'Yedek olusturuldu: ${file.path}',
          'Backup created: ${file.path}',
        ),
      );
    });
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
        title: context.tr('Yedekten Geri Yukleme', 'Restore Backup'),
        body: context.tr(
          'Secilen yedek yuklendiginde mevcut kayitlar degisecek.',
          'Current records will be replaced.',
        ),
        okText: context.tr('Geri Yukle', 'Restore'),
      );
      if (!confirm) return;
      final content = await selected.readAsString();
      final count = widget.store.importFromJsonString(content);
      if (!mounted) return;
      _snack(
        context.tr(
          '$count kayit geri yuklendi.',
          '$count records restored.',
        ),
      );
    });
  }

  Future<void> _clearAllRecords() async {
    final confirm = await _confirm(
      title: context.tr('Tum Veriler Silinsin mi?', 'Delete All Data?'),
      body: context.tr(
        'Bu islem geri alinamaz.',
        'This action cannot be undone.',
      ),
      okText: context.tr('Tumunu Sil', 'Delete All'),
    );
    if (!confirm) return;
    widget.store.clearAllRecords();
    if (!mounted) return;
    _snack(context.tr('Tum veriler silindi.', 'All data deleted.'));
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
            'PassRoot, hassas bilgileri modern bir kasada yonetmeniz icin tasarlanmistir.',
            'PassRoot is designed for managing sensitive data in a modern vault.',
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
            'Veriler varsayilan olarak cihazinizda saklanir. Disa aktarma veya yedekleme dosyalarinin guvenliginden kullanici sorumludur.',
            'Data is stored on your device by default. You are responsible for protecting exported or backup files.',
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
            'Sik Sorulanlar:\n1) Guclu parola kullanin.\n2) Ayni sifreleri tekrar etmeyin.\n3) Duzenli yedek alin.\n\nDestek: support@passroot.app',
            'FAQ:\n1) Use strong passwords.\n2) Avoid reused passwords.\n3) Create backups regularly.\n\nSupport: support@passroot.app',
          ),
        ),
      ),
    );
  }

  Future<void> _sendFeedback() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final inset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, inset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: context.tr('Mesaj', 'Message'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Gonder', 'Send')),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (!mounted) return;
    _snack(context.tr('Geri bildiriminiz alindi.', 'Feedback received.'));
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, widget.settingsStore]),
      builder: (context, _) {
        final settings = widget.settingsStore.settings;
        final strongCount = widget.store.strongRecords.length;
        final weakCount = widget.store.weakRecords.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pr.panelSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pr.panelBorder),
                boxShadow: [
                  BoxShadow(
                    color: pr.panelShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                context.tr(
                  'Guvenlik, veri yonetimi ve gorunum ayarlarinizi buradan yonetin.',
                  'Manage security, data, and appearance settings here.',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Guvenlik', 'Security'),
              children: [
                _switchTile(
                  icon: Icons.lock_outline_rounded,
                  title: context.tr('Uygulama Kilidi', 'App Lock'),
                  subtitle: context.tr(
                    'Uygulama acilisinda kilit kullan',
                    'Require lock on app access',
                  ),
                  value: settings.appLockEnabled,
                  onChanged: (value) {
                    widget.settingsStore.setAppLockEnabled(value);
                  },
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.pin_outlined,
                  title: context.tr('PIN Kodu Ayarlama', 'Set PIN Code'),
                  subtitle: settings.hasPinCode
                      ? context.tr('PIN aktif', 'PIN is active')
                      : context.tr('PIN tanimlayin', 'Set a PIN'),
                  onTap: _managePin,
                ),
                const SizedBox(height: 8),
                _switchTile(
                  icon: Icons.fingerprint_rounded,
                  title: context.tr('Biyometrik Giris', 'Biometric Login'),
                  subtitle: widget.settingsStore.biometricSupported
                      ? context.tr(
                          'Parmak izi / yuz tanima',
                          'Fingerprint / face ID',
                        )
                      : context.tr(
                          'Biyometrik destek yok',
                          'Biometric support unavailable',
                        ),
                  value: settings.biometricEnabled,
                  onChanged:
                      settings.appLockEnabled &&
                          widget.settingsStore.biometricSupported
                      ? (value) =>
                            widget.settingsStore.setBiometricEnabled(value)
                      : null,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.timer_outlined,
                  title: context.tr('Otomatik Kilit Suresi', 'Auto-Lock Duration'),
                  subtitle: context.tr(
                    'Secili: ${settings.autoLockOption.localizedLabel(context)}',
                    'Selected: ${settings.autoLockOption.localizedLabel(context)}',
                  ),
                  onTap: _pickAutoLock,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.notifications_active_outlined,
                  title: context.tr('Guvenlik Bildirimleri', 'Security Alerts'),
                  subtitle: context.tr(
                    'Uyari tercihlerini duzenle',
                    'Edit warning preferences',
                  ),
                  onTap: _openNotificationSettings,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Veri Yonetimi', 'Data Management'),
              children: [
                _actionTile(
                  icon: Icons.backup_rounded,
                  title: context.tr('Yedekleme', 'Backup'),
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
                  title: context.tr('Geri Yukleme', 'Restore'),
                  subtitle: context.tr(
                    'Yedekten veri yukle',
                    'Restore data from backup',
                  ),
                  onTap: _ioBusy ? null : _restoreBackup,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.file_upload_rounded,
                  title: context.tr('Verileri Disa Aktar', 'Export Data'),
                  subtitle: context.tr(
                    'JSON olarak disa aktar',
                    'Export as JSON',
                  ),
                  onTap: _ioBusy ? null : _exportData,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.file_download_rounded,
                  title: context.tr('Verileri Ice Aktar', 'Import Data'),
                  subtitle: context.tr(
                    'JSON dosyasindan ice aktar',
                    'Import from JSON file',
                  ),
                  onTap: _ioBusy ? null : _importData,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.delete_forever_rounded,
                  title: context.tr('Tum Verileri Sil', 'Delete All Data'),
                  subtitle: context.tr(
                    'Bu islem geri alinamaz',
                    'This action cannot be undone',
                  ),
                  danger: true,
                  onTap: _clearAllRecords,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Gorunum', 'Appearance'),
              children: [
                _switchTile(
                  icon: Icons.dark_mode_outlined,
                  title: context.tr('Karanlik Mod', 'Dark Mode'),
                  subtitle: context.tr('Tema gorunumu', 'Theme appearance'),
                  value: settings.darkMode,
                  onChanged: (value) {
                    widget.settingsStore.setDarkMode(value);
                  },
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.palette_outlined,
                  title: context.tr('Tema Rengi', 'Theme Color'),
                  subtitle: context.tr(
                    'Secili: ${settings.themeAccent.localizedLabel(context)}',
                    'Selected: ${settings.themeAccent.localizedLabel(context)}',
                  ),
                  onTap: _pickThemeAccent,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.view_quilt_outlined,
                  title: context.tr('Kart Gorunumu', 'Card Appearance'),
                  subtitle: context.tr(
                    'Secili: ${settings.cardStyle.localizedLabel(context)}',
                    'Selected: ${settings.cardStyle.localizedLabel(context)}',
                  ),
                  onTap: _pickCardStyle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Genel', 'General'),
              children: [
                _actionTile(
                  icon: Icons.language_rounded,
                  title: context.tr('Dil Secimi', 'Language'),
                  subtitle: context.tr(
                    'Secili: ${settings.language.localizedLabel(context)}',
                    'Selected: ${settings.language.localizedLabel(context)}',
                  ),
                  onTap: _pickLanguage,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.password_rounded,
                  title: context.tr(
                    'Sifre Uretici Ayarlari',
                    'Password Generator Settings',
                  ),
                  subtitle: context.tr('Parola kurallari', 'Password rules'),
                  onTap: _openPasswordGeneratorSettings,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.info_outline_rounded,
                  title: context.tr('Hakkinda', 'About'),
                  subtitle: context.tr('Uygulama bilgisi', 'About the app'),
                  onTap: _openAbout,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: context.tr('Gizlilik Politikasi', 'Privacy Policy'),
                  subtitle: context.tr('Veri kullanim bilgisi', 'Data policy'),
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
                  icon: Icons.feedback_outlined,
                  title: context.tr('Geri Bildirim Gonder', 'Send Feedback'),
                  subtitle: context.tr('Mesajini ilet', 'Share your feedback'),
                  onTap: _sendFeedback,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon: Icons.verified_rounded,
                  title: context.tr('Surum Bilgisi', 'App Version'),
                  subtitle: _appVersion,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: context.tr('Kullanici Bilgileri', 'User Information'),
              children: [
                _summaryRow(
                  context.tr('Toplam Kayit', 'Total Records'),
                  '${widget.store.totalCount}',
                ),
                _summaryRow(
                  context.tr('Favori Kayit', 'Favorite Records'),
                  '${widget.store.favoriteCount}',
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
          ],
        );
      },
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
    final iconColor = danger ? scheme.error : scheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: pr.softFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pr.panelBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: pr.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
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
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: pr.iconMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pr.softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pr.panelBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: pr.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: pr.softFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pr.panelBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ],
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
    final pr = context.pr;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pr.panelSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: pr.panelBorder),
            ),
            child: Text(
              body,
              style: const TextStyle(height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
