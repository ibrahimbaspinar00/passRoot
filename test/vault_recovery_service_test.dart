import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/services/biometric_auth_service.dart';
import 'package:passroot/services/encrypted_vault_storage_service.dart';
import 'package:passroot/services/pin_security_service.dart';
import 'package:passroot/services/vault_key_service.dart';
import 'package:passroot/services/vault_recovery_service.dart';
import 'package:passroot/state/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultRecoveryService', () {
    late _InMemorySecureStorage fakeStorage;
    late PinSecurityService pinService;
    late VaultKeyService keyService;
    late AppSettingsStore settingsStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      fakeStorage = _InMemorySecureStorage();
      pinService = PinSecurityService(secureStorageService: fakeStorage);
      keyService = VaultKeyService(
        secureStorage: fakeStorage,
        pinSecurityService: pinService,
      );
      settingsStore = AppSettingsStore(
        pinSecurityService: pinService,
        vaultKeyService: keyService,
      );
      await settingsStore.load();
    });

    test('biometric reset updates PIN', () async {
      await keyService.setupVault(pin: '8273');
      await settingsStore.refreshPinAvailability(notify: false);
      await settingsStore.setBiometricUnlockEnabled(true);

      final recovery = VaultRecoveryService(
        vaultKeyService: keyService,
        settingsStore: settingsStore,
        biometricAuthService: _FakeBiometricAuthService(
          available: true,
          result: const BiometricAuthResult.success(),
        ),
      );

      await recovery.resetPinWithBiometric(reason: 'test', newPin: '7391');

      keyService.lockVault();
      final oldPin = await keyService.unlockWithPin('8273');
      final newPin = await keyService.unlockWithPin('7391');
      expect(oldPin.success, isFalse);
      expect(newPin.success, isTrue);
    });

    test('forgot pin flow fails when biometric is disabled', () async {
      await keyService.setupVault(pin: '8273');
      await settingsStore.refreshPinAvailability(notify: false);
      await settingsStore.setBiometricUnlockEnabled(false);

      final recovery = VaultRecoveryService(
        vaultKeyService: keyService,
        settingsStore: settingsStore,
        biometricAuthService: _FakeBiometricAuthService(
          available: true,
          result: const BiometricAuthResult.success(),
        ),
      );

      await expectLater(
        recovery.resetPinWithBiometric(reason: 'test', newPin: '7391'),
        throwsA(isA<VaultRecoveryException>()),
      );
    });

    test('vault reset clears key material and secure state', () async {
      await keyService.setupVault(pin: '8273');
      await settingsStore.refreshPinAvailability(notify: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('passroot_onboarding_seen_v1', true);

      final fakeEncryptedStorage = _FakeEncryptedVaultStorageService();
      final recovery = VaultRecoveryService(
        vaultKeyService: keyService,
        settingsStore: settingsStore,
        biometricAuthService: _FakeBiometricAuthService(
          available: true,
          result: const BiometricAuthResult.success(),
        ),
        encryptedStorageService: fakeEncryptedStorage,
      );

      await recovery.resetVaultCompletely();

      expect(fakeEncryptedStorage.cleared, isTrue);
      expect(await keyService.hasVaultKeyMaterial(), isFalse);
      expect(await pinService.hasPin(), isFalse);
      expect(settingsStore.pinAvailable, isFalse);
      expect(prefs.getBool('passroot_onboarding_seen_v1'), isNull);
    });

    test('reset leaves app in onboarding-precondition state', () async {
      await keyService.setupVault(pin: '8273');
      await settingsStore.refreshPinAvailability(notify: false);

      final recovery = VaultRecoveryService(
        vaultKeyService: keyService,
        settingsStore: settingsStore,
        biometricAuthService: _FakeBiometricAuthService(
          available: true,
          result: const BiometricAuthResult.success(),
        ),
        encryptedStorageService: _FakeEncryptedVaultStorageService(),
      );

      await recovery.resetVaultCompletely();

      expect(await keyService.hasVaultKeyMaterial(), isFalse);
      expect(settingsStore.pinAvailable, isFalse);
    });
  });
}

class _InMemorySecureStorage extends SecureStorageService {
  _InMemorySecureStorage() : super(storage: const FlutterSecureStorage());

  final Map<String, String> _memory = <String, String>{};

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }
}

class _FakeEncryptedVaultStorageService extends EncryptedVaultStorageService {
  _FakeEncryptedVaultStorageService();

  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
  }
}

class _FakeBiometricAuthService extends BiometricAuthService {
  _FakeBiometricAuthService({required this.available, required this.result});

  final bool available;
  final BiometricAuthResult result;

  @override
  Future<bool> canUseBiometrics() async => available;

  @override
  Future<BiometricAuthResult> authenticateDetailed({
    required String reason,
  }) async {
    return result;
  }
}
