import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../screens/security/biometric_opt_in_screen.dart';
import '../screens/security/create_vault_credentials_screen.dart';
import '../screens/security/lock_screen.dart';
import '../screens/security/pin_login_screen.dart';
import '../screens/security/pin_recovery_screen.dart';
import '../screens/splash_screen.dart';
import '../security/security_service.dart';
import '../security/session_manager.dart';
import '../services/biometric_auth_service.dart';
import '../services/vault_key_service.dart';
import '../services/vault_recovery_service.dart';
import '../widgets/pin_dialogs.dart';
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
  late SecurityService _securityService;
  late final SessionManager _sessionManager;
  late VaultKeyService _vaultKeyService;
  late final BiometricAuthService _biometricAuthService;
  late VaultRecoveryService _vaultRecoveryService;

  bool _pinAvailable = false;
  bool _didGoBackground = false;
  DateTime? _backgroundAt;
  bool _pinRouteOpen = false;
  int _launchFlowId = 0;
  bool _needsVaultSetup = false;
  bool _biometricAvailable = false;
  bool _biometricBusy = false;
  bool _showBiometricPrompt = false;
  bool _biometricPromptBusy = false;
  String? _biometricPromptError;
  bool _recoveryBusy = false;
  String? _recoveryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vaultKeyService = widget.settingsStore.vaultKeyService;
    _biometricAuthService = BiometricAuthService();
    _securityService = SecurityService(
      vaultKeyService: _vaultKeyService,
      biometricAuthService: _biometricAuthService,
    );
    _vaultRecoveryService = VaultRecoveryService(
      vaultKeyService: _vaultKeyService,
      settingsStore: widget.settingsStore,
      biometricAuthService: _biometricAuthService,
    );
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
    _vaultKeyService = widget.settingsStore.vaultKeyService;
    _securityService = SecurityService(
      vaultKeyService: _vaultKeyService,
      biometricAuthService: _biometricAuthService,
    );
    _vaultRecoveryService = VaultRecoveryService(
      vaultKeyService: _vaultKeyService,
      settingsStore: widget.settingsStore,
      biometricAuthService: _biometricAuthService,
    );
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
    final hasVaultKeyMaterial = await _vaultKeyService.hasVaultKeyMaterial();
    final biometricAvailable = await _biometricAuthService.canUseBiometrics();

    if (!mounted || flowId != _launchFlowId) {
      return;
    }

    setState(() {
      _needsVaultSetup = !hasVaultKeyMaterial || !_pinAvailable;
      _biometricAvailable = biometricAvailable;
      _showBiometricPrompt = false;
      _biometricPromptError = null;
    });

    if (_needsVaultSetup) {
      _sessionManager.requirePinSetup(
        errorText: context.tr(
          'Ilk acilis guvenlik adimi: PIN olusturun.',
          'First security step: create your PIN.',
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
    await _openPinLogin();
  }

  Future<void> _onBiometricUnlockPressed() async {
    if (_biometricBusy || !_sessionManager.isLocked) {
      return;
    }
    if (!_biometricAvailable ||
        !widget.settingsStore.settings.biometricUnlockEnabled) {
      _sessionManager.endAuthentication(
        errorText: context.tr(
          'Biyometrik dogrulama kullanilamiyor. PIN ile devam edin.',
          'Biometric authentication is unavailable. Continue with PIN.',
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

    try {
      await _vaultKeyService.unlockWithBiometricSession();
      if (!mounted) return;
      _sessionManager.unlock();
    } on VaultKeyException catch (error) {
      _sessionManager.endAuthentication(errorText: error.message);
    } on Exception {
      _sessionManager.endAuthentication(
        errorText: context.tr(
          'Biyometrik dogrulama tamamlandi ancak kasa acilamadi. PIN ile tekrar deneyin.',
          'Biometric verification passed but vault unlock failed. Retry with PIN.',
        ),
      );
    }
  }

  String _biometricFailureMessage(BiometricAuthFailureReason? reason) {
    switch (reason) {
      case BiometricAuthFailureReason.notEnrolled:
      case BiometricAuthFailureReason.unavailable:
      case BiometricAuthFailureReason.noCredentials:
        return context.tr(
          'Biyometrik dogrulama kullanilamiyor. PIN ile devam edin.',
          'Biometric authentication is unavailable. Continue with PIN.',
        );
      case BiometricAuthFailureReason.temporaryLockout:
      case BiometricAuthFailureReason.permanentLockout:
        return context.tr(
          'Biyometrik dogrulama gecici olarak kilitlendi. PIN ile devam edin.',
          'Biometric authentication is temporarily locked. Continue with PIN.',
        );
      case BiometricAuthFailureReason.timedOut:
        return context.tr(
          'Biyometrik zaman asimina ugradi. PIN ile devam edin.',
          'Biometric authentication timed out. Continue with PIN.',
        );
      case BiometricAuthFailureReason.fallbackRequested:
        return context.tr(
          'Biyometrik yerine alternatif dogrulama secildi. PIN ile devam edin.',
          'Alternative authentication was requested instead of biometrics. Continue with PIN.',
        );
      case BiometricAuthFailureReason.noActivity:
      case BiometricAuthFailureReason.invalidActivity:
      case BiometricAuthFailureReason.unknown:
        return context.tr(
          'Biyometrik dogrulama baslatilamadi. PIN ile devam edin.',
          'Biometric authentication could not start. Continue with PIN.',
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
          onVerifyPin: (pin) => _securityService.verifyPinDetailed(
            settingsStore: widget.settingsStore,
            pin: pin,
          ),
          onForgotPin: _openPinRecoveryFlow,
        ),
      ),
    );
    _pinRouteOpen = false;

    if (!mounted) return false;

    if (verified == true) {
      _sessionManager.unlock();
      return true;
    }
    if (verified == null) {
      _sessionManager.endAuthentication();
      return false;
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

  Future<void> _openPinRecoveryFlow() async {
    if (!_sessionManager.isLocked || _recoveryBusy) {
      return;
    }
    if (!mounted) {
      return;
    }

    final recoveryAvailable =
        _biometricAvailable &&
        widget.settingsStore.settings.biometricUnlockEnabled;
    _recoveryError = null;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            Future<void> biometricResetPin() async {
              if (_recoveryBusy) {
                return;
              }
              final resetReason = context.tr(
                'PIN sifirlama islemi icin biyometrik dogrulama yapin.',
                'Authenticate biometrically to reset PIN.',
              );
              final pinResetFailedMessage = context.tr(
                'PIN sifirlama tamamlanamadi. Lutfen tekrar deneyin.',
                'PIN reset could not be completed. Please try again.',
              );
              final newPin = await PinDialogs.askNewPin(
                context,
                barrierDismissible: false,
                title: context.tr('Yeni PIN Belirle', 'Set New PIN'),
                description: context.tr(
                  'Biyometrik dogrulama sonrasi yeni PIN tanimlanacak.',
                  'A new PIN will be set after biometric verification.',
                ),
                actionText: context.tr('PIN Kaydet', 'Save PIN'),
              );
              if (newPin == null) {
                return;
              }
              setState(() {
                _recoveryBusy = true;
                _recoveryError = null;
              });
              try {
                await _vaultRecoveryService.resetPinWithBiometric(
                  reason: resetReason,
                  newPin: newPin,
                );
                if (!context.mounted) return;
                _sessionManager.unlock();
                Navigator.of(context).pop();
              } on VaultRecoveryException catch (error) {
                setState(() {
                  _recoveryError = error.message;
                });
              } on Exception {
                setState(() {
                  _recoveryError = pinResetFailedMessage;
                });
              } finally {
                if (context.mounted) {
                  setState(() {
                    _recoveryBusy = false;
                  });
                }
              }
            }

            Future<void> resetVault() async {
              if (_recoveryBusy) {
                return;
              }
              final resetFailedMessage = context.tr(
                'Kasa sifirlama tamamlanamadi. Lutfen tekrar deneyin.',
                'Vault reset could not be completed. Please try again.',
              );
              final confirmed = await _confirmVaultReset();
              if (!confirmed) {
                return;
              }

              setState(() {
                _recoveryBusy = true;
                _recoveryError = null;
              });
              try {
                await _vaultRecoveryService.resetVaultCompletely();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                await _prepareLaunchFlow();
              } on VaultRecoveryException catch (error) {
                setState(() {
                  _recoveryError = error.message;
                });
              } on Exception {
                setState(() {
                  _recoveryError = resetFailedMessage;
                });
              } finally {
                if (context.mounted) {
                  setState(() {
                    _recoveryBusy = false;
                  });
                }
              }
            }

            return PinRecoveryScreen(
              biometricRecoveryAvailable: recoveryAvailable,
              busy: _recoveryBusy,
              errorText: _recoveryError,
              onBiometricResetPin: biometricResetPin,
              onResetVault: resetVault,
            );
          },
        ),
      ),
    );
  }

  Future<bool> _confirmVaultReset() async {
    final typed = TextEditingController();
    String? localError;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Kasayi Sifirla', 'Reset Vault')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      'Bu islem tum yerel kasayi siler, mevcut verilere erisimi kaybettirir ve geri alinamaz.',
                      'This action deletes the entire local vault, removes access to current data, and cannot be undone.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      'Onaylamak icin RESET yazin.',
                      'Type RESET to confirm.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typed,
                    decoration: InputDecoration(
                      labelText: context.tr('Onay Kodu', 'Confirmation Code'),
                      errorText: localError,
                    ),
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
                    if (typed.text.trim().toUpperCase() != 'RESET') {
                      setDialogState(() {
                        localError = context.tr(
                          'Lutfen RESET yazarak onaylayin.',
                          'Please type RESET to confirm.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(
                    context.tr('Kalici Olarak Sil', 'Delete Permanently'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    typed.dispose();
    return confirmed == true;
  }

  Future<void> _createInitialCredentials(VaultCredentialSetupData data) async {
    if (!_sessionManager.beginPinSetup()) return;

    try {
      await _vaultKeyService.setupVault(pin: data.pin);
      await widget.settingsStore.refreshPinAvailability(notify: false);
      if (!mounted) return;
      _pinAvailable = widget.settingsStore.pinAvailable;
      final shouldSuggestBiometric =
          _biometricAvailable &&
          !widget.settingsStore.settings.biometricUnlockEnabled;
      setState(() {
        _needsVaultSetup = false;
        _showBiometricPrompt = shouldSuggestBiometric;
        _biometricPromptBusy = false;
        _biometricPromptError = null;
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

  Future<void> _enableBiometricFromPrompt() async {
    if (_biometricPromptBusy) {
      return;
    }
    setState(() {
      _biometricPromptBusy = true;
      _biometricPromptError = null;
    });
    final ok = await _biometricAuthService.authenticate(
      reason: context.tr(
        'PassRoot icin biyometrik girisi etkinlestirmeyi onaylayin.',
        'Confirm enabling biometric unlock for PassRoot.',
      ),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _biometricPromptBusy = false;
        _biometricPromptError = context.tr(
          'Biyometrik dogrulama tamamlanamadi. PIN ile devam edebilirsiniz.',
          'Biometric verification was not completed. You can continue with PIN.',
        );
      });
      return;
    }
    await widget.settingsStore.setBiometricUnlockEnabled(true);
    if (!mounted) return;
    setState(() {
      _showBiometricPrompt = false;
      _biometricPromptBusy = false;
      _biometricPromptError = null;
    });
  }

  Future<void> _skipBiometricPrompt() async {
    if (_biometricPromptBusy) {
      return;
    }
    setState(() {
      _showBiometricPrompt = false;
      _biometricPromptError = null;
    });
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

        if (_showBiometricPrompt) {
          return BiometricOptInScreen(
            busy: _biometricPromptBusy,
            errorText: _biometricPromptError,
            onEnable: _enableBiometricFromPrompt,
            onSkip: _skipBiometricPrompt,
          );
        }

        if (_sessionManager.isLocked) {
          final settings = widget.settingsStore.settings;
          final showBiometric =
              settings.biometricUnlockEnabled && _biometricAvailable;
          return LockScreen(
            title: context.tr('PassRoot Kilidi', 'PassRoot Lock'),
            subtitle: context.tr(
              'Devam etmek icin PIN veya biyometri ile kimliginizi dogrulayin.',
              'Verify your identity with PIN or biometrics to continue.',
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
