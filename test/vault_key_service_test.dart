import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/services/pin_security_service.dart';
import 'package:passroot/services/vault_key_service.dart';

void main() {
  group('VaultKeyService', () {
    late _InMemorySecureStorage fakeStorage;
    late PinSecurityService pinSecurityService;
    late VaultKeyService service;

    setUp(() {
      fakeStorage = _InMemorySecureStorage();
      pinSecurityService = PinSecurityService(
        secureStorageService: fakeStorage,
      );
      service = VaultKeyService(
        secureStorage: fakeStorage,
        pinSecurityService: pinSecurityService,
      );
    });

    test('unlocks with valid PIN and fails with wrong PIN', () async {
      await service.setupVault(pin: '8273');
      service.lockVault();

      final wrongPin = await service.unlockWithPin('1111');
      expect(wrongPin.success, isFalse);

      final okPin = await service.unlockWithPin('8273');
      expect(okPin.success, isTrue);
      expect(service.hasUnlockedDek, isTrue);
    });

    test(
      'returns key-missing error when vault key material is absent',
      () async {
        await service.setupVault(pin: '8273');
        await fakeStorage.delete('passroot_vault_dek_device_v3');

        service.lockVault();
        final result = await service.unlockWithPin('8273');
        expect(result.success, isFalse);
      },
    );
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
