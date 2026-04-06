import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/lang_x.dart';
import '../models/vault_record.dart';
import '../screens/dashboard_screen.dart';
import '../screens/record_form_screen.dart';
import '../screens/security_detail_screen.dart';
import '../screens/settings_page.dart';
import '../screens/storage_recovery_screen.dart';
import '../screens/vault_screen.dart';
import '../state/account_store.dart';
import '../state/app_settings_store.dart';
import '../state/google_auth_store.dart';
import '../state/vault_store.dart';
import 'app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.settingsStore,
    required this.accountStore,
    required this.googleAuthStore,
    this.vaultStore,
  });

  final AppSettingsStore settingsStore;
  final AccountStore accountStore;
  final GoogleAuthStore googleAuthStore;
  final VaultStore? vaultStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _onboardingSeenKey = 'passroot_onboarding_seen_v1';

  late final VaultStore _store;
  late final List<Widget> _pages;
  late final ValueNotifier<int> _settingsFocusSignal;
  late final bool _ownsStore;
  int _index = 0;
  bool _recoveryBusy = false;
  bool _onboardingChecked = false;
  bool _storeLoading = true;
  VaultStorageIssue? _storeIssue;

  @override
  void initState() {
    super.initState();
    _store = widget.vaultStore ?? VaultStore();
    _ownsStore = widget.vaultStore == null;
    _settingsFocusSignal = ValueNotifier<int>(0);
    _pages = <Widget>[
      DashboardScreen(
        key: const PageStorageKey<String>('dashboard-screen'),
        store: _store,
        googleAuthStore: widget.googleAuthStore,
        onOpenSignIn: _openSettingsForSignIn,
        onOpenDetail: _openSecurityDetail,
      ),
      VaultScreen(
        key: const PageStorageKey<String>('vault-screen'),
        store: _store,
        settingsStore: widget.settingsStore,
        onCreate: _openCreateRecord,
        onEdit: _openEditRecord,
      ),
      SettingsPage(
        key: const PageStorageKey<String>('settings-screen'),
        store: _store,
        settingsStore: widget.settingsStore,
        accountStore: widget.accountStore,
        googleAuthStore: widget.googleAuthStore,
        focusGoogleAuthSignal: _settingsFocusSignal,
      ),
    ];
    _storeLoading = _store.isLoading;
    _storeIssue = _store.storageIssue;
    _store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStoreChanged());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    if (_ownsStore) {
      _store.dispose();
    }
    _settingsFocusSignal.dispose();
    super.dispose();
  }

  void _openSettingsForSignIn() {
    setState(() {
      _index = 2;
    });
    _settingsFocusSignal.value = _settingsFocusSignal.value + 1;
  }

  void _onStoreChanged() {
    final nextLoading = _store.isLoading;
    final nextIssue = _store.storageIssue;
    final shellStateChanged =
        _storeLoading != nextLoading || !_sameIssue(_storeIssue, nextIssue);
    if (shellStateChanged && mounted) {
      setState(() {
        _storeLoading = nextLoading;
        _storeIssue = nextIssue;
      });
    }

    if (_onboardingChecked || _store.isLoading || _store.hasStorageIssue) {
      return;
    }
    _onboardingChecked = true;
    unawaited(_showOnboardingIfNeeded());
  }

  bool _sameIssue(VaultStorageIssue? a, VaultStorageIssue? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.code == b.code &&
        a.title == b.title &&
        a.message == b.message &&
        a.type == b.type;
  }

  Future<void> _showOnboardingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_onboardingSeenKey) == true;
    if (seen || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr(
              'PassRoot Vault\'a Hos Geldiniz',
              'Welcome to PassRoot Vault',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  'PassRoot hassas veriler icin tasarlanmistir. Guvenli kullanim icin asagidaki kurallari izleyin:',
                  'PassRoot is built for sensitive data. Follow these rules for safe use:',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  '- Vault sifresi master password ile korunur; unutursaniz kasa acilamaz.',
                  '- Vault is protected by master password; if forgotten, vault cannot be unlocked.',
                ),
              ),
              Text(
                context.tr(
                  '- PIN/biyometrik sadece hizli acilis katmanidir; master password mutlaka guclu olmali.',
                  '- PIN/biometric is only a quick-unlock layer; master password must be strong.',
                ),
              ),
              Text(
                context.tr(
                  '- Yedekleri her zaman sifreli (.pvault) formatta alin.',
                  '- Always use encrypted (.pvault) backups.',
                ),
              ),
              Text(
                context.tr(
                  '- Duz metin JSON/CSV import sadece riskli gelismis secenektir.',
                  '- Plain JSON/CSV import is an advanced risky option.',
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Guvenli Baslat', 'Start Securely')),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    await prefs.setBool(_onboardingSeenKey, true);
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreateRecord() async {
    final result = await Navigator.push<VaultRecord>(
      context,
      MaterialPageRoute<VaultRecord>(
        builder: (_) => RecordFormScreen(settingsStore: widget.settingsStore),
      ),
    );
    if (result == null) return;
    try {
      await _store.addRecord(result);
    } on VaultStoreException catch (error) {
      _snack(error.message);
    }
  }

  Future<void> _openEditRecord(VaultRecord record) async {
    final result = await Navigator.push<VaultRecord>(
      context,
      MaterialPageRoute<VaultRecord>(
        builder: (_) => RecordFormScreen(
          initial: record,
          settingsStore: widget.settingsStore,
        ),
      ),
    );
    if (result == null) return;
    try {
      await _store.updateRecord(result);
    } on VaultStoreException catch (error) {
      _snack(error.message);
    }
  }

  Future<void> _openSecurityDetail(SecurityDetailType type) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SecurityDetailScreen(type: type, store: _store),
      ),
    );
  }

  Future<void> _retryStorageLoad() async {
    if (_recoveryBusy) return;
    setState(() {
      _recoveryBusy = true;
    });
    try {
      await _store.retryLoadFromStorage();
    } on VaultStoreException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _recoveryBusy = false;
        });
      }
    }
  }

  Future<void> _clearCorruptedStorage() async {
    if (_recoveryBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr('Bozuk Veriyi Temizle', 'Clear Corrupted Data'),
          ),
          content: Text(
            context.tr(
              'Bu işlem yerel bozuk kasa verisini siler. Ardından yedekten geri yükleyebilirsiniz. Devam edilsin mi?',
              'This removes corrupted local vault data. You can restore from backup afterwards. Continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('İptal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Temizle', 'Clear')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _recoveryBusy = true;
    });
    try {
      await _store.clearCorruptedStorage();
      if (!mounted) {
        return;
      }
      setState(() {
        _index = 2;
      });
      _snack(
        context.tr(
          'Bozuk yerel veri temizlendi. Ayarlar bölümünden yedek geri yükleme yapabilirsiniz.',
          'Corrupted local data was cleared. You can restore a backup from Settings.',
        ),
      );
    } on VaultStoreException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _recoveryBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    if (_storeLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  'Kasa verisi hazırlanıyor...',
                  'Preparing vault data...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final issue = _storeIssue;
    if (issue != null) {
      return StorageRecoveryScreen(
        issue: issue,
        busy: _recoveryBusy,
        onRetry: _retryStorageLoad,
        onOpenRestoreSettings: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(context.tr('Kurtarma', 'Recovery'))),
                body: SettingsPage(
                  store: _store,
                  settingsStore: widget.settingsStore,
                  accountStore: widget.accountStore,
                  googleAuthStore: widget.googleAuthStore,
                  focusGoogleAuthSignal: _settingsFocusSignal,
                ),
              ),
            ),
          );
        },
        onResetCorruptedVault: _clearCorruptedStorage,
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pr.canvasGradientTop, pr.canvasGradientBottom],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(index: _index, children: _pages),
        ),
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: _openCreateRecord,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Yeni Kayıt', 'New Record')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grid_view_rounded),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: context.tr('Ana Sayfa', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.lock_person_outlined),
            selectedIcon: const Icon(Icons.lock_person_rounded),
            label: context.tr('Kasa', 'Vault'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('Ayarlar', 'Settings'),
          ),
        ],
      ),
    );
  }
}
