import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/models/vault_record.dart';
import 'package:passroot/services/encrypted_vault_storage_service.dart';
import 'package:passroot/state/vault_store.dart';

void main() {
  group('VaultStore storage failures', () {
    test('reports corrupted payload issue when decrypt fails', () async {
      final store = VaultStore(
        storageService: _FakeEncryptedStorageService(
          loadError: const EncryptedVaultStorageException(
            code: EncryptedVaultStorageErrorCode.decryptionFailed,
            message: 'decrypt failed',
          ),
        ),
      );
      addTearDown(store.dispose);

      await _waitUntilLoaded(store);

      expect(store.hasStorageIssue, isTrue);
      expect(store.storageIssue?.type, VaultStorageIssueType.corruptedPayload);
      expect(store.totalCount, 0);
    });

    test(
      'throws on persist failure and keeps in-memory state consistent',
      () async {
        final fakeStorage = _FakeEncryptedStorageService();
        final store = VaultStore(storageService: fakeStorage);
        addTearDown(store.dispose);

        await _waitUntilLoaded(store);

        fakeStorage.saveError = const EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.writeFailed,
          message: 'write failed',
        );

        await expectLater(
          store.addRecord(_sampleRecord()),
          throwsA(isA<VaultStoreException>()),
        );

        expect(store.totalCount, 0);
        expect(store.storageIssue?.type, VaultStorageIssueType.writeFailure);
      },
    );
  });
}

Future<void> _waitUntilLoaded(VaultStore store) async {
  for (var i = 0; i < 50; i++) {
    if (!store.isLoading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('VaultStore did not finish loading in test timeout.');
}

VaultRecord _sampleRecord() {
  final now = DateTime.now();
  return VaultRecord(
    id: 'sample-1',
    title: 'Test',
    category: RecordCategory.website,
    platform: 'example.com',
    accountName: 'user',
    password: 'Secret#123',
    note: '',
    websiteOrDescription: 'https://example.com',
    isFavorite: false,
    securityNote: '',
    securityTag: '',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeEncryptedStorageService extends EncryptedVaultStorageService {
  _FakeEncryptedStorageService({this.loadError});

  final Exception? loadError;
  Exception? saveError;
  String? savedPayload;

  @override
  Future<String?> loadJsonPayload() async {
    if (loadError != null) {
      throw loadError!;
    }
    return null;
  }

  @override
  Future<void> saveJsonPayload(String jsonPayload) async {
    if (saveError != null) {
      throw saveError!;
    }
    savedPayload = jsonPayload;
  }

  @override
  Future<void> clear() async {}
}
