import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_settings_store.dart';
import 'biometric_auth_service.dart';
import 'encrypted_vault_storage_service.dart';
import 'vault_file_service.dart';
import 'vault_key_service.dart';

class VaultRecoveryService {
  VaultRecoveryService({
    required VaultKeyService vaultKeyService,
    required AppSettingsStore settingsStore,
    BiometricAuthService? biometricAuthService,
    EncryptedVaultStorageService? encryptedStorageService,
  }) : _vaultKeyService = vaultKeyService,
       _settingsStore = settingsStore,
       _biometricAuthService = biometricAuthService ?? BiometricAuthService(),
       _encryptedStorageService =
           encryptedStorageService ?? EncryptedVaultStorageService();

  static const String _onboardingSeenKey = 'passroot_onboarding_seen_v1';

  final VaultKeyService _vaultKeyService;
  final AppSettingsStore _settingsStore;
  final BiometricAuthService _biometricAuthService;
  final EncryptedVaultStorageService _encryptedStorageService;

  Future<void> resetPinWithBiometric({
    required String reason,
    required String newPin,
  }) async {
    final settings = _settingsStore.settings;
    if (!settings.biometricUnlockEnabled) {
      throw const VaultRecoveryException(
        'Biyometrik dogrulama kapali. Bu cihazda PIN kurtarma kullanilamiyor.',
      );
    }
    final available = await _biometricAuthService.canUseBiometrics();
    if (!available) {
      throw const VaultRecoveryException(
        'Bu cihazda biyometrik dogrulama kullanilamiyor.',
      );
    }
    final biometricResult = await _biometricAuthService.authenticateDetailed(
      reason: reason,
    );
    if (!biometricResult.success) {
      throw const VaultRecoveryException(
        'Biyometrik dogrulama tamamlanamadi. PIN kurtarma basarisiz.',
      );
    }

    await _vaultKeyService.unlockWithBiometricSession();
    await _settingsStore.setPinCode(newPin);
    _vaultKeyService.lockVault();
  }

  Future<void> resetVaultCompletely() async {
    await _encryptedStorageService.clear();
    await _vaultKeyService.clearAllKeyMaterial();
    await _settingsStore.resetAfterVaultReset();
    await VaultFileService.clearLastImportPath();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingSeenKey);
  }
}

class VaultRecoveryException implements Exception {
  const VaultRecoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}
