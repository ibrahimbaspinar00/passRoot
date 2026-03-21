import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/services/encrypted_vault_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EncryptedVaultStorageService', () {
    late _InMemorySecureStorage fakeStorage;
    late EncryptedVaultStorageService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      fakeStorage = _InMemorySecureStorage();
      service = EncryptedVaultStorageService(secureStorage: fakeStorage);
    });

    test('writes encrypted payload and reads back decrypted json', () async {
      const plain = '[{"id":"1","title":"Demo"}]';
      await service.saveJsonPayload(plain);

      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('passroot_vault_encrypted_payload_v1');
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(plain));

      final loaded = await service.loadJsonPayload();
      expect(loaded, plain);
    });

    test('migrates legacy plaintext payload into encrypted store', () async {
      const plain = '[{"id":"2","title":"Legacy"}]';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'passroot_vault_records_v2': plain,
      });

      final migrated = await service.loadJsonPayload();
      expect(migrated, plain);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('passroot_vault_records_v2'), isNull);
      expect(prefs.getString('passroot_vault_encrypted_payload_v1'), isNotNull);
    });

    test('throws explicit error when encrypted payload is corrupted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'passroot_vault_encrypted_payload_v1': '{broken-json',
      });

      await expectLater(
        service.loadJsonPayload(),
        throwsA(
          isA<EncryptedVaultStorageException>().having(
            (error) => error.code,
            'code',
            EncryptedVaultStorageErrorCode.decryptionFailed,
          ),
        ),
      );
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
