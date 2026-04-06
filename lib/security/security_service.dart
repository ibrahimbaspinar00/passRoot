import '../state/app_settings_store.dart';
import '../services/pin_security_service.dart';
import '../services/vault_key_service.dart';

class SecurityService {
  SecurityService({VaultKeyService? vaultKeyService})
    : _vaultKeyService = vaultKeyService ?? VaultKeyService();

  final VaultKeyService _vaultKeyService;

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

  Future<VaultUnlockResult> verifyMasterPasswordDetailed(String masterPassword) {
    return _vaultKeyService.unlockWithMasterPasswordDetailed(masterPassword);
  }

  Future<bool> verifyMasterPassword(String masterPassword) {
    return _vaultKeyService.unlockWithMasterPassword(masterPassword);
  }

  void lockVault() {
    _vaultKeyService.lockVault();
  }
}
