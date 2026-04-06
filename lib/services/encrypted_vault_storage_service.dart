import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vault_crypto_service.dart';
import 'vault_key_service.dart';

class EncryptedVaultStorageService {
  EncryptedVaultStorageService({
    VaultCryptoService? cryptoService,
    VaultKeyService? vaultKeyService,
    Future<Directory> Function()? storageDirectoryProvider,
  }) : _cryptoService = cryptoService ?? VaultCryptoService(),
       _vaultKeyService = vaultKeyService ?? VaultKeyService(),
       _storageDirectoryProvider =
           storageDirectoryProvider ?? getApplicationSupportDirectory;

  static const String _encryptedPayloadPrefsKey =
      'passroot_vault_encrypted_payload_v1';
  static const String _legacyPlainPrefsKey = 'passroot_vault_records_v2';
  static const String _legacyAlgorithmId = 'aes256gcm-pbkdf2-sha256-v1';
  static const String _newAlgorithmId = 'aes256gcm-key-v1';
  static const String _storageFileName = 'passroot_vault_secure_payload_v2';
  static const String _storageBackupFileName =
      'passroot_vault_secure_payload_v2.bak';

  final VaultCryptoService _cryptoService;
  final VaultKeyService _vaultKeyService;
  final Future<Directory> Function() _storageDirectoryProvider;
  Future<void> _ioQueue = Future<void>.value();

  Future<String?> loadJsonPayload() async {
    final stored = await _runLocked(_readEncryptedPayloadFromStorage);
    final storedPayload = stored?.payload;
    if ((storedPayload ?? '').isEmpty) {
      final legacyRaw = await _runLocked(_readLegacyPlainPayload);
      if ((legacyRaw ?? '').isEmpty) {
        return null;
      }
      final legacyPlain = legacyRaw!.trim();
      if (legacyPlain.isEmpty) {
        return null;
      }
      if (_vaultKeyService.hasUnlockedDek) {
        await saveJsonPayload(legacyPlain);
        await _runLocked(_removeLegacyPlainPayload);
      }
      return legacyPlain;
    }

    final payload = storedPayload!.trim();
    if (payload.isEmpty) {
      return null;
    }

    final algorithm = _readAlgorithm(payload);
    if (algorithm == _newAlgorithmId) {
      final dek = _vaultKeyService.requireUnlockedDek();
      try {
        final plain = await _cryptoService.decryptStringWithRawKey(
          encryptedPayload: payload,
          rawKey: dek,
        );
        if (stored?.fromPrefs == true) {
          await _runLocked(() async {
            await _writeEncryptedPayloadToFile(payload);
            await _removeLegacyPrefsPayload();
          });
        }
        return plain;
      } on VaultCryptoException catch (error) {
        final fallback = await _tryRecoverFromBackup(dek: dek);
        if (fallback != null) {
          return fallback;
        }
        throw EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.decryptionFailed,
          message:
              'Kasa verisi cozumlenemedi. Dogrulama basarisiz veya veri bozuk.',
          cause: error,
        );
      } on FormatException catch (error) {
        throw EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.invalidPayload,
          message: 'Kasa verisi bozuk veya eksik gorunuyor.',
          cause: error,
        );
      }
    }

    if (algorithm == _legacyAlgorithmId) {
      final legacySecret = await _vaultKeyService.readLegacyMasterSecret();
      if ((legacySecret ?? '').trim().isEmpty) {
        throw const EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.legacyMigrationRequired,
          message:
              'Kasa verisi eski surumde kalmis. Gecis icin once yeni kasayi ayarlayin.',
        );
      }
      try {
        final plain = await _cryptoService.decryptString(
          encryptedPayload: payload,
          passphrase: legacySecret!.trim(),
        );
        if (_vaultKeyService.hasUnlockedDek) {
          await saveJsonPayload(plain);
          await _vaultKeyService.deleteLegacyMasterSecret();
        }
        return plain;
      } on VaultCryptoException catch (error) {
        final fallback = await _tryRecoverFromBackupWithLegacySecret(
          legacySecret: legacySecret!.trim(),
        );
        if (fallback != null) {
          return fallback;
        }
        throw EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.decryptionFailed,
          message:
              'Kasa verisi cozumlenemedi. Eski sifreleme verisi bozulmus olabilir.',
          cause: error,
        );
      }
    }

    throw const EncryptedVaultStorageException(
      code: EncryptedVaultStorageErrorCode.invalidPayload,
      message: 'Kasa verisi bilinmeyen bir sifreleme bicimi kullaniyor.',
    );
  }

  Future<void> saveJsonPayload(String jsonPayload) async {
    final normalized = jsonPayload.trim();
    if (normalized.isEmpty) {
      throw const EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.invalidPayload,
        message: 'Bos kasa verisi kaydedilemez.',
      );
    }

    final dek = _vaultKeyService.requireUnlockedDek();
    final encryptedPayload = await _cryptoService.encryptStringWithRawKey(
      plaintext: normalized,
      rawKey: dek,
    );
    await _runLocked(() async {
      await _writeEncryptedPayloadToFile(encryptedPayload);
      await _removeLegacyPrefsPayload();
    });
  }

  Future<void> clear() async {
    await _runLocked(() async {
      await _removeEncryptedPayloadFromFile();
      await _removeBackupPayloadFromFile();
      await _removeLegacyPrefsPayload();
      await _removeLegacyPlainPayload();
    });
  }

  String? _readAlgorithm(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return (decoded['alg'] as String?)?.trim();
    } on FormatException {
      return null;
    }
  }

  Future<_StoredEncryptedPayload?> _readEncryptedPayloadFromStorage() async {
    final file = await _storageFile();
    if (await file.exists()) {
      try {
        return _StoredEncryptedPayload(
          payload: await file.readAsString(encoding: utf8),
          fromPrefs: false,
        );
      } on Exception catch (error) {
        throw EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.readFailed,
          message: 'Kasa depolama dosyasi okunamadi.',
          cause: error,
        );
      }
    }

    final prefs = await _prefsOrThrow();
    final payload = prefs.getString(_encryptedPayloadPrefsKey)?.trim();
    if ((payload ?? '').isEmpty) {
      return null;
    }
    return _StoredEncryptedPayload(payload: payload!, fromPrefs: true);
  }

  Future<void> _writeEncryptedPayloadToFile(String payload) async {
    final file = await _storageFile();
    final backupFile = await _backupStorageFile();
    final tmpFile = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await tmpFile.writeAsString(payload, flush: true, encoding: utf8);
      if (await file.exists()) {
        await _createBackupFromPrimary(file: file, backupFile: backupFile);
        await file.delete();
      }
      await tmpFile.rename(file.path);
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.writeFailed,
        message: 'Kasa verisi dosyaya yazilamadi.',
        cause: error,
      );
    } finally {
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    }
  }

  Future<void> _removeEncryptedPayloadFromFile() async {
    final file = await _storageFile();
    if (!await file.exists()) {
      return;
    }
    try {
      await file.delete();
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.writeFailed,
        message: 'Kasa dosyasi silinemedi.',
        cause: error,
      );
    }
  }

  Future<void> _removeBackupPayloadFromFile() async {
    final backup = await _backupStorageFile();
    if (!await backup.exists()) {
      return;
    }
    try {
      await backup.delete();
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.writeFailed,
        message: 'Kasa yedek dosyasi silinemedi.',
        cause: error,
      );
    }
  }

  Future<File> _storageFile() async {
    final base = await _storageDirectoryProvider();
    return File(p.join(base.path, _storageFileName));
  }

  Future<File> _backupStorageFile() async {
    final base = await _storageDirectoryProvider();
    return File(p.join(base.path, _storageBackupFileName));
  }

  Future<String?> _readLegacyPlainPayload() async {
    final prefs = await _prefsOrThrow();
    return prefs.getString(_legacyPlainPrefsKey)?.trim();
  }

  Future<void> _removeLegacyPlainPayload() async {
    final prefs = await _prefsOrThrow();
    await prefs.remove(_legacyPlainPrefsKey);
  }

  Future<void> _removeLegacyPrefsPayload() async {
    final prefs = await _prefsOrThrow();
    await prefs.remove(_encryptedPayloadPrefsKey);
  }

  Future<SharedPreferences> _prefsOrThrow() async {
    try {
      return await SharedPreferences.getInstance();
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.readFailed,
        message: 'Kasa depolama alanina erisilemedi.',
        cause: error,
      );
    }
  }

  Future<T> _runLocked<T>(Future<T> Function() action) {
    final op = _ioQueue.then((_) => action());
    _ioQueue = op.then<void>((_) {}, onError: (_, stackTrace) {});
    return op;
  }

  Future<void> _createBackupFromPrimary({
    required File file,
    required File backupFile,
  }) async {
    try {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      final contents = await file.readAsString(encoding: utf8);
      await backupFile.writeAsString(contents, flush: true, encoding: utf8);
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.writeFailed,
        message: 'Kasa yedek dosyasi olusturulamadi.',
        cause: error,
      );
    }
  }

  Future<String?> _tryRecoverFromBackup({required List<int> dek}) async {
    final backupPayload = await _runLocked(_readBackupPayloadFromFile);
    if ((backupPayload ?? '').isEmpty) {
      return null;
    }
    try {
      final plain = await _cryptoService.decryptStringWithRawKey(
        encryptedPayload: backupPayload!,
        rawKey: dek,
      );
      await _runLocked(() => _writeEncryptedPayloadToFile(backupPayload));
      return plain;
    } on Exception {
      return null;
    }
  }

  Future<String?> _tryRecoverFromBackupWithLegacySecret({
    required String legacySecret,
  }) async {
    final backupPayload = await _runLocked(_readBackupPayloadFromFile);
    if ((backupPayload ?? '').isEmpty) {
      return null;
    }
    try {
      return await _cryptoService.decryptString(
        encryptedPayload: backupPayload!,
        passphrase: legacySecret,
      );
    } on Exception {
      return null;
    }
  }

  Future<String?> _readBackupPayloadFromFile() async {
    final backup = await _backupStorageFile();
    if (!await backup.exists()) {
      return null;
    }
    try {
      return await backup.readAsString(encoding: utf8);
    } on Exception {
      return null;
    }
  }
}

class _StoredEncryptedPayload {
  const _StoredEncryptedPayload({
    required this.payload,
    required this.fromPrefs,
  });

  final String payload;
  final bool fromPrefs;
}

enum EncryptedVaultStorageErrorCode {
  readFailed,
  writeFailed,
  invalidPayload,
  decryptionFailed,
  secureStorageUnavailable,
  legacyMigrationRequired,
}

class EncryptedVaultStorageException implements Exception {
  const EncryptedVaultStorageException({
    required this.code,
    required this.message,
    this.cause,
  });

  final EncryptedVaultStorageErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
