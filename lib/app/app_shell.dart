import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import '../models/app_settings.dart';
import '../models/vault_record.dart';
import '../services/biometric_service.dart';
import '../services/firebase_account_service.dart';
import '../screens/dashboard_screen.dart';
import '../screens/record_form_screen.dart';
import '../screens/security_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/vault_screen.dart';
import '../l10n/lang_x.dart';
import '../state/app_settings_store.dart';
import '../state/vault_store.dart';
import '../widgets/app_lock_overlay.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.settingsStore});

  final AppSettingsStore settingsStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final VaultStore _store;
  late final BiometricService _biometricService;
  FirebaseAccountService? _firebaseAccountService;
  late final List<Widget> _pages;
  int _index = 0;
  bool _locked = false;
  bool _sessionSignOutInProgress = false;
  DateTime? _pausedAt;
  DateTime? _lastInteractionAt;
  DateTime? _lastSessionActivityAt;
  Timer? _inactivityTimer;
  Timer? _sessionTimer;
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = VaultStore();
    _biometricService = BiometricService();
    if (Firebase.apps.isNotEmpty) {
      _firebaseAccountService = FirebaseAccountService();
    }
    _pages = <Widget>[
      DashboardScreen(
        key: const PageStorageKey<String>('dashboard-screen'),
        store: _store,
        onOpenDetail: _openSecurityDetail,
      ),
      VaultScreen(
        key: const PageStorageKey<String>('vault-screen'),
        store: _store,
        settingsStore: widget.settingsStore,
        onCreate: _openCreateRecord,
        onEdit: _openEditRecord,
      ),
      SettingsScreen(
        key: const PageStorageKey<String>('settings-screen'),
        store: _store,
        settingsStore: widget.settingsStore,
      ),
    ];
    _authStateSubscription = _firebaseAccountService?.userChanges().listen((_) {
      _lastSessionActivityAt = DateTime.now();
      _resetSessionTimer();
    });
    widget.settingsStore.addListener(_onSettingsChanged);
    if (widget.settingsStore.settings.appLockEnabled) {
      _locked = true;
    }
    _onSettingsChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settingsStore.removeListener(_onSettingsChanged);
    _inactivityTimer?.cancel();
    _sessionTimer?.cancel();
    _authStateSubscription?.cancel();
    _store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = widget.settingsStore.settings;
    if (!settings.appLockEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final duration = settings.autoLockOption.duration;
      final now = DateTime.now();
      final shouldLock =
          duration == Duration.zero ||
          (_pausedAt != null && now.difference(_pausedAt!) >= duration);
      _pausedAt = null;
      if (shouldLock) {
        _lockApp();
      } else {
        _resetInactivityTimer();
      }
      unawaited(_enforceSessionTimeoutOnResume());
    }
  }

  void _onSettingsChanged() {
    final settings = widget.settingsStore.settings;
    if (!settings.appLockEnabled && _locked) {
      setState(() {
        _locked = false;
      });
    }
    _resetInactivityTimer();
    _resetSessionTimer();
  }

  void _onUserInteraction() {
    if (_locked) return;
    final now = DateTime.now();
    final last = _lastInteractionAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 320)) {
      return;
    }
    _lastInteractionAt = now;
    _resetInactivityTimer();
    _lastSessionActivityAt = now;
    _resetSessionTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    final settings = widget.settingsStore.settings;
    if (!settings.appLockEnabled) return;
    final duration = settings.autoLockOption.duration;
    if (duration == Duration.zero) return;
    _inactivityTimer = Timer(duration, _lockApp);
  }

  Duration? _sessionTimeoutDuration() {
    final settings = widget.settingsStore.settings;
    final accountService = _firebaseAccountService;
    if (!settings.firebaseSessionTimeoutEnabled) return null;
    if (accountService == null) return null;
    final user = accountService.currentUser;
    if (user == null || user.isAnonymous) return null;
    return settings.firebaseSessionTimeoutOption.duration;
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    final timeout = _sessionTimeoutDuration();
    if (timeout == null) return;

    final now = DateTime.now();
    final lastActivity = _lastSessionActivityAt ?? now;
    _lastSessionActivityAt = lastActivity;
    final elapsed = now.difference(lastActivity);
    if (elapsed >= timeout) {
      unawaited(_expireSession());
      return;
    }
    _sessionTimer = Timer(timeout - elapsed, () {
      unawaited(_expireSession());
    });
  }

  Future<void> _enforceSessionTimeoutOnResume() async {
    final timeout = _sessionTimeoutDuration();
    if (timeout == null) return;
    final now = DateTime.now();
    final lastActivity = _lastSessionActivityAt ?? now;
    _lastSessionActivityAt = lastActivity;
    if (now.difference(lastActivity) >= timeout) {
      await _expireSession();
      return;
    }
    _resetSessionTimer();
  }

  Future<void> _expireSession() async {
    if (!mounted || _sessionSignOutInProgress) return;
    final timeout = _sessionTimeoutDuration();
    if (timeout == null) return;

    final lastActivity = _lastSessionActivityAt ?? DateTime.now();
    if (DateTime.now().difference(lastActivity) < timeout) {
      _resetSessionTimer();
      return;
    }

    _sessionSignOutInProgress = true;
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Guvenlik icin oturum suresi doldu. Lutfen yeniden giris yapin.',
              'Session expired for security. Please sign in again.',
            ),
          ),
        ),
      );
      await _firebaseAccountService?.signOut();
    } catch (_) {
      // Keep timeout sign-out resilient even if provider sign-out fails.
    } finally {
      _sessionSignOutInProgress = false;
      _sessionTimer?.cancel();
      _lastSessionActivityAt = null;
    }
  }

  void _lockApp() {
    if (!mounted || _locked || !widget.settingsStore.settings.appLockEnabled) {
      return;
    }
    setState(() {
      _locked = true;
    });
  }

  Future<bool> _tryBiometricUnlock() async {
    if (!widget.settingsStore.settings.biometricEnabled) return false;
    final ok = await _biometricService.authenticate();
    if (!mounted) return false;
    if (ok) {
      setState(() {
        _locked = false;
      });
      _resetInactivityTimer();
    }
    return ok;
  }

  Future<void> _unlockByButton() async {
    final settings = widget.settingsStore.settings;
    if (settings.hasPinCode) {
      final verified = await _verifyPinCode(settings.pinCode!);
      if (!mounted || !verified) {
        return;
      }
    }
    setState(() {
      _locked = false;
    });
    _resetInactivityTimer();
  }

  Future<bool> _verifyPinCode(String pin) async {
    final controller = TextEditingController();
    var hidden = true;
    var error = '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('PIN Dogrulama', 'PIN Verification')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: hidden,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: context.tr('PIN Kodu', 'PIN Code'),
                      errorText: error.isEmpty ? null : error,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            hidden = !hidden;
                          });
                        },
                        icon: Icon(
                          hidden
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      final ok = controller.text.trim() == pin;
                      if (ok) {
                        Navigator.pop(context, true);
                        return;
                      }
                      setDialogState(() {
                        error = context.tr('PIN hatali.', 'Incorrect PIN.');
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final ok = controller.text.trim() == pin;
                    if (ok) {
                      Navigator.pop(context, true);
                      return;
                    }
                    setDialogState(() {
                      error = context.tr('PIN hatali.', 'Incorrect PIN.');
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

  Future<void> _openCreateRecord() async {
    _onUserInteraction();
    final result = await Navigator.push<VaultRecord>(
      context,
      MaterialPageRoute<VaultRecord>(
        builder: (_) => RecordFormScreen(settingsStore: widget.settingsStore),
      ),
    );
    if (result == null) return;
    _store.addRecord(result);
  }

  Future<void> _openEditRecord(VaultRecord record) async {
    _onUserInteraction();
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
    _store.updateRecord(result);
  }

  Future<void> _openSecurityDetail(SecurityDetailType type) async {
    _onUserInteraction();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SecurityDetailScreen(type: type, store: _store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _onUserInteraction(),
        onPointerSignal: (_) => _onUserInteraction(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pr.canvasGradientTop, pr.canvasGradientBottom],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(index: _index, children: _pages),
                ),
                if (_locked)
                  Positioned.fill(
                    child: AppLockOverlay(
                      onUnlock: _unlockByButton,
                      biometricEnabled:
                          widget.settingsStore.settings.biometricEnabled,
                      onUseBiometric: _tryBiometricUnlock,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: _openCreateRecord,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Yeni Kayit', 'New Record')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        onDestinationSelected: (value) {
          _onUserInteraction();
          setState(() {
            _index = value;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: context.tr('Ana Sayfa', 'Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_person_outlined),
            selectedIcon: Icon(Icons.lock_person_rounded),
            label: context.tr('Kasa', 'Vault'),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: context.tr('Ayarlar', 'Settings'),
          ),
        ],
      ),
    );
  }
}
