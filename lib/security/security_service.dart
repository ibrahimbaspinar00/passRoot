import '../state/app_settings_store.dart';
import '../services/pin_security_service.dart';

class SecurityService {
  Future<void> prepare(AppSettingsStore settingsStore) async {
    await settingsStore.refreshPinAvailability(notify: false);
  }

  Future<bool> verifyPin({
    required AppSettingsStore settingsStore,
    required String pin,
  }) async {
    final result = await settingsStore.verifyPinDetailed(pin);
    return result.success;
  }

  Future<PinVerificationResult> verifyPinDetailed({
    required AppSettingsStore settingsStore,
    required String pin,
  }) {
    return settingsStore.verifyPinDetailed(pin);
  }
}
