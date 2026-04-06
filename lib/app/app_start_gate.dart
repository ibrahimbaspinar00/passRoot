import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../screens/security/create_vault_credentials_screen.dart';
import '../screens/security/lock_screen.dart';
import '../screens/security/master_unlock_screen.dart';
import '../screens/security/pin_login_screen.dart';
import '../screens/splash_screen.dart';
import '../security/security_service.dart';
import '../security/session_manager.dart';
import '../services/biometric_auth_service.dart';
import '../services/vault_key_service.dart';
import '../state/account_store.dart';
import '../state/app_settings_store.dart';
import '../state/google_auth_store.dart';
import '../utils/app_logger.dart';
import 'app_shell.dart';

class AppStartGate extends StatefulWidget {
  const AppStartGate({
    super.key,
    required this.settingsStore,
    required this.accountStore,
    required this.googleAuthStore,
  });

  final AppSettingsStore settingsStore;
  final AccountStore accountStore;
  final GoogleAuthStore googleAuthStore;

  @override
  State<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<AppStartGate>
    with WidgetsBindingObserver {
  late final SecurityService _securityService;
  late final SessionManager _sessionManager;
  late final VaultKeyService _vaultKeyService;
  late final BiometricAuthService _biometricAuthService;

  bool _pinAvailable = false;
  bool _didGoBackground = false;
  DateTime? _backgroundAt;
  bool _pinRouteOpen = false;
  bool _masterRouteOpen = false;
  int _launchFlowId = 0;
  bool _needsVaultSetup = false;
  bool _biometricAvailable = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vaultKeyService = widget.settingsStore.vaultKeyService;
    _securityService = SecurityService(vaultKeyService: _vaultKeyService);
    _sessionManager = SessionManager();
    _biometricAuthService = BiometricAuthService();
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
    _vaultKeyService = widget.settingsStore.vaultKeyService;
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

    if (!_sessionManager.isUnlocked) {
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

    _vaultKeyService.lockVault();
    _sessionManager.lock(
      errorText: context.tr(
        'Uygulama arka plandan dondu. Devam etmek icin kimliginizi dogrulayin.',
        'App returned from background. Verify your identity to continue.',
      ),
    );
  }

  Future<void> _prepareLaunchFlow() async {
    final flowId = ++_launchFlowId;
    _sessionManager.startBooting();

    await _securityService.prepare(widget.settingsStore);
    _pinAvailable = widget.settingsStore.pinAvailable;
    final hasMasterWrap = await _vaultKeyService.hasMasterWrap();
    final biometricAvailable = await _biometricAuthService.canUseBiometrics();

    if (!mounted || flowId != _launchFlowId) {
      return;
    }

    setState(() {
      _needsVaultSetup = !hasMasterWrap;
      _biometricAvailable = biometricAvailable;
    });

    if (_needsVaultSetup) {
      _sessionManager.requirePinSetup(
        errorText: context.tr(
          'Ilk acilis: kasa anahtarini guvenli bicimde olusturmaniz gerekir.',
          'First launch: you must securely create vault credentials.',
        ),
      );
      return;
    }

    _vaultKeyService.lockVault();
    _sessionManager.lock(
      errorText: context.tr(
        'Kasa acmak icin kimlik dogrulama gerekli.',
        'Authentication is required to unlock the vault.',
      ),
    );
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final hasPin = widget.settingsStore.pinAvailable;
    if (_pinAvailable != hasPin) {
      _pinAvailable = hasPin;
    }
  }

  Future<void> _onUnlockPressed() async {
    if (!_sessionManager.isLocked) return;
    if (_pinAvailable) {
      await _openPinLogin();
      return;
    }
    await _openMasterLogin();
  }

  Future<void> _onBiometricUnlockPressed() async {
    if (_biometricBusy || !_sessionManager.isLocked) {
      return;
    }
    if (!_biometricAvailable ||
        !widget.settingsStore.settings.biometricUnlockEnabled) {
      _sessionManager.endAuthentication(
        errorText: context.tr(
          'Biyometrik dogrulama kullanilamiyor. PIN veya master password ile devam edin.',
          'Biometric authentication is unavailable. Continue with PIN or master password.',
        ),
      );
      await _onUnlockPressed();
      return;
    }

    setState(() {
      _biometricBusy = true;
    });
    final biometric = await _biometricAuthService.authenticateDetailed(
      reason: context.tr(
        'PassRoot kasasini acmak icin biyometrik dogrulama yapin.',
        'Authenticate biometrically to unlock PassRoot vault.',
      ),
    );
    if (!mounted) return;
    setState(() {
      _biometricBusy = false;
    });
    if (!biometric.success) {
      final message = _biometricFailureMessage(biometric.failureReason);
      _sessionManager.endAuthentication(errorText: message);
      if (biometric.shouldFallbackToPrimaryUnlock) {
        await _onUnlockPressed();
      }
      return;
    }
    if (_pinAvailable) {
      await _openPinLogin(
        allowBack: false,
        description: context.tr(
          'Biyometrik dogrulama tamamlandi. Devam etmek icin PIN girin.',
          'Biometric verification passed. Enter PIN to continue.',
        ),
      );
      return;
    }
    await _openMasterLogin(
      allowBack: false,
      description: context.tr(
        'Biyometrik dogrulama tamamlandi. Master password girin.',
        'Biometric verification passed. Enter master password.',
      ),
    );
  }

  String _biometricFailureMessage(BiometricAuthFailureReason? reason) {
    switch (reason) {
      case BiometricAuthFailureReason.notEnrolled:
      case BiometricAuthFailureReason.unavailable:
      case BiometricAuthFailureReason.noCredentials:
        return context.tr(
          'Biyometrik dogrulama kullanilamiyor. PIN veya master password ile devam edin.',
          'Biometric authentication is unavailable. Continue with PIN or master password.',
        );
      case BiometricAuthFailureReason.temporaryLockout:
      case BiometricAuthFailureReason.permanentLockout:
        return context.tr(
          'Biyometrik dogrulama gecici olarak kilitlendi. PIN veya master password ile devam edin.',
          'Biometric authentication is temporarily locked. Continue with PIN or master password.',
        );
      case BiometricAuthFailureReason.timedOut:
        return context.tr(
          'Biyometrik zaman asimina ugradi. PIN veya master password ile devam edin.',
          'Biometric authentication timed out. Continue with PIN or master password.',
        );
      case BiometricAuthFailureReason.fallbackRequested:
        return context.tr(
          'Biyometrik yerine alternatif dogrulama secildi. PIN veya master password ile devam edin.',
          'Alternative authentication was requested instead of biometrics. Continue with PIN or master password.',
        );
      case BiometricAuthFailureReason.noActivity:
      case BiometricAuthFailureReason.invalidActivity:
      case BiometricAuthFailureReason.unknown:
        return context.tr(
          'Biyometrik dogrulama baslatilamadi. PIN veya master password ile devam edin.',
          'Biometric authentication could not start. Continue with PIN or master password.',
        );
      case BiometricAuthFailureReason.canceledByUser:
      case BiometricAuthFailureReason.systemCanceled:
      case BiometricAuthFailureReason.authInProgress:
        return context.tr(
          'Biyometrik dogrulama tamamlanmadi.',
          'Biometric authentication was not completed.',
        );
      case null:
        return context.tr(
          'Biyometrik dogrulama basarisiz.',
          'Biometric authentication failed.',
        );
    }
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

    var masterFallbackRequested = false;
    _pinRouteOpen = true;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PinLoginScreen(
          allowBack: allowBack,
          description:
              description ??
              context.tr(
                'Uygulamaya giris yapmak icin PIN kodunuzu girin.',
                'Enter your PIN to access the app.',
              ),
          onForgotPin: () async {
            masterFallbackRequested = true;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(false);
            }
          },
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
      await widget.settingsStore.pinSecurityService
          .clearMasterReauthRequirement();
      _sessionManager.unlock();
      return true;
    }

    if (masterFallbackRequested) {
      _sessionManager.endAuthentication();
      return _openMasterLogin(
        allowBack: allowBack,
        description: context.tr(
          'PIN yerine master password ile devam edin.',
          'Continue with master password instead of PIN.',
        ),
      );
    }

    _securityService.lockVault();
    _sessionManager.endAuthentication(
      errorText: allowBack
          ? context.tr(
              'PIN girisi iptal edildi. Tekrar deneyin.',
              'PIN entry was canceled. Please try again.',
            )
          : context.tr(
              'Devam etmek icin PIN kodu gerekir.',
              'PIN is required to continue.',
            ),
    );
    return false;
  }

  Future<bool> _openMasterLogin({
    bool allowBack = true,
    String? description,
  }) async {
    if (!_sessionManager.isLocked || _masterRouteOpen) {
      return false;
    }
    if (!_sessionManager.beginAuthentication()) {
      return false;
    }
    _masterRouteOpen = true;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MasterUnlockScreen(
          allowBack: allowBack,
          description:
              description ??
              context.tr(
                'Kasa anahtarini acmak icin master password girin.',
                'Enter master password to unlock vault key.',
              ),
          onVerifyMasterPassword: _securityService.verifyMasterPasswordDetailed,
        ),
      ),
    );
    _masterRouteOpen = false;
    if (!mounted) return false;

    if (verified == true) {
      _sessionManager.unlock();
      return true;
    }
    _securityService.lockVault();
    _sessionManager.endAuthentication(
      errorText: context.tr(
        'Master password dogrulanamadi.',
        'Master password verification failed.',
      ),
    );
    return false;
  }

  Future<void> _createInitialCredentials(VaultCredentialSetupData data) async {
    if (!_sessionManager.beginPinSetup()) return;

    try {
      await _vaultKeyService.setupVault(
        masterPassword: data.masterPassword,
        optionalPin: data.pin,
      );
      await widget.settingsStore.refreshPinAvailability(notify: false);
      if (!mounted) return;
      _pinAvailable = widget.settingsStore.pinAvailable;
      setState(() {
        _needsVaultSetup = false;
      });
      _sessionManager.unlock();
    } on VaultKeyException catch (error) {
      _sessionManager.endPinSetupWithError(error.message);
    } on Exception catch (error, stackTrace) {
      AppLogger.debug(
        'AppStartGate',
        'Vault setup failed',
        error: error,
        stackTrace: stackTrace,
      );
      _sessionManager.endPinSetupWithError(
        context.tr(
          'Kasa kurulumu tamamlanamadi. Lutfen tekrar deneyin.',
          'Vault setup failed. Please try again.',
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

        if (_needsVaultSetup) {
          return CreateVaultCredentialsScreen(
            onSubmit: _createInitialCredentials,
            busy: _sessionManager.isPinSetupBusy,
            errorText: _sessionManager.errorText,
          );
        }

        if (_sessionManager.isLocked) {
          final settings = widget.settingsStore.settings;
          final showBiometric =
              settings.biometricUnlockEnabled && _biometricAvailable;
          return LockScreen(
            title: context.tr('PassRoot Kilidi', 'PassRoot Lock'),
            subtitle: context.tr(
              'Devam etmek icin kimliginizi dogrulayin.',
              'Verify your identity to continue.',
            ),
            busy: _sessionManager.isAuthenticating || _biometricBusy,
            errorText: _sessionManager.errorText,
            onUnlockPressed: _onUnlockPressed,
            onBiometricUnlock: _onBiometricUnlockPressed,
            showBiometricUnlock: showBiometric,
          );
        }

        return AppShell(
          settingsStore: widget.settingsStore,
          accountStore: widget.accountStore,
          googleAuthStore: widget.googleAuthStore,
        );
      },
    );
  }
}
