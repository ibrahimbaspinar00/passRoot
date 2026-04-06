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

    test(
      'separates invalid master password from corrupted key material',
      () async {
        const master = 'correct horse battery staple';
        await service.setupVault(
          masterPassword: master,
          optionalPin: '82739452',
        );
        service.lockVault();

        final wrongPassword = await service.unlockWithMasterPasswordDetailed(
          'wrong password 987654',
        );
        expect(wrongPassword.success, isFalse);
        expect(wrongPassword.reason, VaultUnlockFailureReason.invalidSecret);

        await fakeStorage.write(
          key: 'passroot_vault_dek_master_wrap_v2',
          value: '{broken-json',
        );
        service.lockVault();
        final corrupted = await service.unlockWithMasterPasswordDetailed(
          master,
        );
        expect(corrupted.success, isFalse);
        expect(corrupted.reason, VaultUnlockFailureReason.keyMaterialCorrupted);
      },
    );

    test('returns missing material error when no master wrap exists', () async {
      final result = await service.unlockWithMasterPasswordDetailed(
        'any-valid-length-password',
      );
      expect(result.success, isFalse);
      expect(result.reason, VaultUnlockFailureReason.keyMaterialMissing);
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
