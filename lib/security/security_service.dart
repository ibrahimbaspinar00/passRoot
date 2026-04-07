import '../state/app_settings_store.dart';
import '../services/biometric_auth_service.dart';
import '../services/pin_security_service.dart';
import '../services/vault_key_service.dart';

class SecurityService {
  SecurityService({
    VaultKeyService? vaultKeyService,
    BiometricAuthService? biometricAuthService,
  }) : _vaultKeyService = vaultKeyService ?? VaultKeyService(),
       _biometricAuthService = biometricAuthService ?? BiometricAuthService();

  final VaultKeyService _vaultKeyService;
  final BiometricAuthService _biometricAuthService;

  Future<void> prepare(AppSettingsStore settingsStore) async {
    await settingsStore.refreshPinAvailability(notify: false);
  }

  Future<bool> verifyPin({
    required AppSettingsStore settingsStore,
    required String pin,
  }) async {
    final result = await _vaultKeyService.unlockWithPin(pin);
    return result.success;
  }

  Future<PinVerificationResult> verifyPinDetailed({
    required AppSettingsStore settingsStore,
    required String pin,
  }) {
    return _vaultKeyService.unlockWithPin(pin);
  }

  Future<bool> unlockWithBiometric({required String reason}) async {
    final biometricResult = await _biometricAuthService.authenticateDetailed(
      reason: reason,
    );
    if (!biometricResult.success) {
      return false;
    }
    await _vaultKeyService.unlockWithBiometricSession();
    return true;
  }

  void lockVault() {
    _vaultKeyService.lockVault();
  }
}
