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
          store.addRecord(_sampleRecord(id: 'sample-1', title: 'Test')),
          throwsA(isA<VaultStoreException>()),
        );

        expect(store.totalCount, 0);
        expect(store.storageIssue?.type, VaultStorageIssueType.writeFailure);
      },
    );

    test('serializes concurrent writes to avoid lost updates', () async {
      final fakeStorage = _FakeEncryptedStorageService(
        saveDelay: const Duration(milliseconds: 40),
      );
      final store = VaultStore(storageService: fakeStorage);
      addTearDown(store.dispose);

      await _waitUntilLoaded(store);

      final first = _sampleRecord(id: 'sample-1', title: 'Test');
      final second = _sampleRecord(id: 'sample-2', title: 'Second');

      await Future.wait<void>([
        store.addRecord(first),
        store.addRecord(second),
      ]);

      expect(store.totalCount, 2);
      expect(store.records.any((record) => record.id == first.id), isTrue);
      expect(store.records.any((record) => record.id == second.id), isTrue);
    });
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

VaultRecord _sampleRecord({required String id, required String title}) {
  final now = DateTime.now();
  return VaultRecord(
    id: id,
    title: title,
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
  _FakeEncryptedStorageService({
    this.loadError,
    this.saveDelay = Duration.zero,
  });

  final Exception? loadError;
  final Duration saveDelay;
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
    if (saveDelay > Duration.zero) {
      await Future<void>.delayed(saveDelay);
    }
    if (saveError != null) {
      throw saveError!;
    }
    savedPayload = jsonPayload;
  }

  @override
  Future<void> clear() async {}
}
