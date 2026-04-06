import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/services/encrypted_vault_storage_service.dart';
import 'package:passroot/services/pin_security_service.dart';
import 'package:passroot/services/vault_key_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptedVaultStorageService', () {
    late _InMemorySecureStorage fakeStorage;
    late VaultKeyService keyService;
    late EncryptedVaultStorageService service;
    late Directory tempDir;

    Future<EncryptedVaultStorageService> buildService() async {
      return EncryptedVaultStorageService(
        vaultKeyService: keyService,
        storageDirectoryProvider: () async => tempDir,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('passroot-vault-test-');
      fakeStorage = _InMemorySecureStorage();
      keyService = VaultKeyService(
        secureStorage: fakeStorage,
        pinSecurityService: PinSecurityService(secureStorageService: fakeStorage),
      );
      await keyService.setupVault(masterPassword: 'MasterPassword!234');
      service = await buildService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes encrypted payload and reads back decrypted json', () async {
      const plain = '[{"id":"1","title":"Demo"}]';
      await service.saveJsonPayload(plain);

      final storageFile = File('${tempDir.path}/passroot_vault_secure_payload_v2');
      final encrypted = await storageFile.readAsString();
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

      final loadedLegacy = await service.loadJsonPayload();
      expect(loadedLegacy, plain);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('passroot_vault_records_v2'), isNull);
      final loadedAfterMigration = await service.loadJsonPayload();
      expect(loadedAfterMigration, plain);

      final storageFile = File('${tempDir.path}/passroot_vault_secure_payload_v2');
      expect(await storageFile.exists(), isTrue);
    });

    test('throws explicit error when encrypted payload is corrupted file', () async {
      final storageFile = File('${tempDir.path}/passroot_vault_secure_payload_v2');
      await storageFile.writeAsString('{broken-json', flush: true);

      await expectLater(
        service.loadJsonPayload(),
        throwsA(
          isA<EncryptedVaultStorageException>().having(
            (error) => error.code,
            'code',
            EncryptedVaultStorageErrorCode.invalidPayload,
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
