import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../screens/security/create_pin_screen.dart';
import '../screens/security/lock_screen.dart';
import '../screens/security/pin_login_screen.dart';
import '../screens/splash_screen.dart';
import '../security/security_service.dart';
import '../security/session_manager.dart';
import '../state/app_settings_store.dart';
import '../utils/app_logger.dart';
import 'app_shell.dart';

class AppStartGate extends StatefulWidget {
  const AppStartGate({super.key, required this.settingsStore});

  final AppSettingsStore settingsStore;

  @override
  State<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<AppStartGate>
    with WidgetsBindingObserver {
  late final SecurityService _securityService;
  late final SessionManager _sessionManager;

  bool _pinAvailable = false;
  bool _didGoBackground = false;
  DateTime? _backgroundAt;
  bool _pinRouteOpen = false;
  int _launchFlowId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _securityService = SecurityService();
    _sessionManager = SessionManager();
    widget.settingsStore.addListener(_onSettingsChanged);
    unawaited(_prepareLaunchFlow());
  }

  @override
  void didUpdateWidget(covariant AppStartGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsStore == widget.settingsStore) {
      return;
    }
    oldWidget.settingsStore.removeListener(_onSettingsChanged);
    widget.settingsStore.addListener(_onSettingsChanged);
    unawaited(_prepareLaunchFlow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settingsStore.removeListener(_onSettingsChanged);
    _sessionManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _didGoBackground = true;
      _backgroundAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed || !_didGoBackground) {
      return;
    }
    _didGoBackground = false;

    if (!_sessionManager.isUnlocked || !_pinAvailable) {
      return;
    }
    final settings = widget.settingsStore.settings;
    if (!settings.appLockEnabled || !settings.lockOnAppResume) {
      return;
    }

    final backgroundAt = _backgroundAt;
    final elapsed = backgroundAt == null
        ? Duration.zero
        : DateTime.now().difference(backgroundAt);
    final timeout = settings.autoLockOption.duration;
    final shouldLock = timeout == Duration.zero || elapsed >= timeout;
    if (!shouldLock) {
      return;
    }

    _sessionManager.lock(
      errorText: context.tr(
        'Uygulama arka plandan döndü. Devam etmek için kimliğinizi doğrulayın.',
        'App returned from background. Verify your identity to continue.',
      ),
    );
  }

  Future<void> _prepareLaunchFlow() async {
    final flowId = ++_launchFlowId;
    _sessionManager.startBooting();

    await _securityService.prepare(widget.settingsStore);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || flowId != _launchFlowId) return;

    _pinAvailable = widget.settingsStore.pinAvailable;
    final settings = widget.settingsStore.settings;
    if (!_pinAvailable) {
      _sessionManager.requirePinSetup(
        errorText: context.tr(
          'PassRoot güvenli başlangıç için PIN oluşturmanızı ister.',
          'PassRoot requires creating a PIN for secure startup.',
        ),
      );
      return;
    }

    if (!settings.appLockEnabled || !settings.lockOnAppLaunch) {
      _sessionManager.unlock();
      return;
    }

    _sessionManager.lock();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final hasPin = widget.settingsStore.pinAvailable;
    if (_pinAvailable != hasPin) {
      _pinAvailable = hasPin;
    }
    if (!_pinAvailable) {
      _sessionManager.requirePinSetup(
        errorText: context.tr(
          'Kasa erişimi için önce bir PIN oluşturmalısınız.',
          'You must create a PIN before accessing the vault.',
        ),
      );
      return;
    }

    if (!widget.settingsStore.settings.appLockEnabled &&
        (_sessionManager.needsPinSetup || _sessionManager.isLocked)) {
      _sessionManager.unlock();
      return;
    }

    if (_sessionManager.needsPinSetup &&
        widget.settingsStore.settings.appLockEnabled) {
      _sessionManager.lock();
    }
  }

  Future<void> _onUnlockPressed() async {
    if (!_sessionManager.isLocked) return;
    if (_pinAvailable) {
      await _openPinLogin();
      return;
    }
    _sessionManager.endAuthentication(
      errorText: context.tr(
        'PIN tanımlı değil. Ayarlardan uygulama şifresi oluşturun.',
        'No app PIN is configured. Create one from settings.',
      ),
    );
  }

  Future<bool> _openPinLogin({
    bool allowBack = true,
    String? description,
  }) async {
    if (!_pinAvailable || !_sessionManager.isLocked || _pinRouteOpen) {
      return false;
    }
    if (!_sessionManager.beginAuthentication()) {
      return false;
    }

    _pinRouteOpen = true;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PinLoginScreen(
          allowBack: allowBack,
          description:
              description ??
              context.tr(
                'Uygulamaya giriş yapmak için PIN kodunuzu girin.',
                'Enter your PIN to access the app.',
              ),
          onVerifyPin: (pin) => _securityService.verifyPinDetailed(
            settingsStore: widget.settingsStore,
            pin: pin,
          ),
        ),
      ),
    );
    _pinRouteOpen = false;

    if (!mounted) return false;

    if (verified == true) {
      _sessionManager.unlock();
      return true;
    }

    _sessionManager.endAuthentication(
      errorText: allowBack
          ? context.tr(
              'PIN girişi iptal edildi. Tekrar deneyin.',
              'PIN entry was canceled. Please try again.',
            )
          : context.tr(
              'Devam etmek için PIN kodunuzu girmeniz gerekir.',
              'You need to enter your PIN to continue.',
            ),
    );
    return false;
  }

  Future<void> _createInitialPin(String pin) async {
    if (!_sessionManager.beginPinSetup()) return;

    try {
      await widget.settingsStore.setPinCode(pin);
      await widget.settingsStore.refreshPinAvailability(notify: false);
      if (!mounted) return;
      _pinAvailable = true;
      _sessionManager.unlock();
    } on Exception catch (error, stackTrace) {
      AppLogger.debug(
        'AppStartGate',
        'PIN kaydedilemedi',
        error: error,
        stackTrace: stackTrace,
      );
      _sessionManager.endPinSetupWithError(
        context.tr(
          'PIN kaydedilirken bir hata oluştu. Lütfen tekrar deneyin.',
          'An error occurred while saving PIN. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionManager,
      builder: (context, _) {
        if (_sessionManager.isBooting) {
          return const SplashScreen();
        }

        if (_sessionManager.needsPinSetup) {
          return CreatePinScreen(
            onSubmitPin: _createInitialPin,
            busy: _sessionManager.isPinSetupBusy,
            errorText: _sessionManager.errorText,
          );
        }

        if (_sessionManager.isLocked) {
          return LockScreen(
            title: context.tr('PassRoot Kilidi', 'PassRoot Lock'),
            subtitle: context.tr(
              'Devam etmek için uygulama PIN kodunuzu girin.',
              'Enter your app password/PIN to continue.',
            ),
            busy: _sessionManager.isAuthenticating,
            errorText: _sessionManager.errorText,
            onUnlockPressed: _onUnlockPressed,
          );
        }

        return AppShell(settingsStore: widget.settingsStore);
      },
    );
  }
}
