import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../security/secure_storage_service.dart';
import 'vault_crypto_service.dart';

class EncryptedVaultStorageService {
  EncryptedVaultStorageService({
    SecureStorageService? secureStorage,
    VaultCryptoService? cryptoService,
  }) : _secureStorage = secureStorage ?? SecureStorageService(),
       _cryptoService = cryptoService ?? VaultCryptoService();

  static const String _encryptedPayloadPrefsKey =
      'passroot_vault_encrypted_payload_v1';
  static const String _legacyPlainPrefsKey = 'passroot_vault_records_v2';
  static const String _masterSecretKey = 'passroot_vault_master_secret_v1';

  final SecureStorageService _secureStorage;
  final VaultCryptoService _cryptoService;

  Future<String?> loadJsonPayload() async {
    final prefs = await _prefsOrThrow();
    final encryptedPayload = prefs.getString(_encryptedPayloadPrefsKey)?.trim();
    if ((encryptedPayload ?? '').isNotEmpty) {
      final masterSecret = await _ensureMasterSecret();
      try {
        return await _cryptoService.decryptString(
          encryptedPayload: encryptedPayload!,
          passphrase: masterSecret,
        );
      } on VaultCryptoException catch (error) {
        throw EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.decryptionFailed,
          message:
              'Kasa verisi çözümlenemedi. Şifreleme verisi bozulmuş olabilir.',
          cause: error,
        );
      } on FormatException catch (error) {
        throw EncryptedVaultStorageException(
          code: EncryptedVaultStorageErrorCode.invalidPayload,
          message: 'Kasa verisi bozuk veya eksik görünüyor.',
          cause: error,
        );
      }
    }

    // Migrate legacy plaintext payload only once, then persist encrypted.
    final legacyRaw = prefs.getString(_legacyPlainPrefsKey)?.trim();
    if ((legacyRaw ?? '').isEmpty) {
      return null;
    }
    final plain = legacyRaw!;
    await saveJsonPayload(plain);
    final removed = await prefs.remove(_legacyPlainPrefsKey);
    if (!removed && prefs.containsKey(_legacyPlainPrefsKey)) {
      throw const EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.writeFailed,
        message: 'Eski kasa verisi güvenli depolamaya taşınamadı.',
      );
    }
    return plain;
  }

  Future<void> saveJsonPayload(String jsonPayload) async {
    final normalized = jsonPayload.trim();
    if (normalized.isEmpty) {
      throw const EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.invalidPayload,
        message: 'Boş kasa verisi kaydedilemez.',
      );
    }

    final passphrase = await _ensureMasterSecret();
    final encryptedPayload = await _cryptoService.encryptString(
      plaintext: normalized,
      passphrase: passphrase,
    );

    final prefs = await _prefsOrThrow();
    final saved = await prefs.setString(
      _encryptedPayloadPrefsKey,
      encryptedPayload,
    );
    if (!saved) {
      throw const EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.writeFailed,
        message: 'Kasa verisi cihaza kaydedilemedi.',
      );
    }
    await prefs.remove(_legacyPlainPrefsKey);
  }

  Future<void> clear() async {
    final prefs = await _prefsOrThrow();
    await prefs.remove(_encryptedPayloadPrefsKey);
    await prefs.remove(_legacyPlainPrefsKey);
  }

  Future<SharedPreferences> _prefsOrThrow() async {
    try {
      return await SharedPreferences.getInstance();
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.readFailed,
        message: 'Kasa depolama alanına erişilemedi.',
        cause: error,
      );
    }
  }

  Future<String> _ensureMasterSecret() async {
    try {
      final existing = await _secureStorage.read(_masterSecretKey);
      if ((existing ?? '').trim().isNotEmpty) {
        return existing!.trim();
      }

      final created = _randomBase64(32);
      await _secureStorage.write(key: _masterSecretKey, value: created);
      return created;
    } on Exception catch (error) {
      throw EncryptedVaultStorageException(
        code: EncryptedVaultStorageErrorCode.secureStorageUnavailable,
        message: 'Güvenli anahtar deposuna erişilemedi.',
        cause: error,
      );
    }
  }

  String _randomBase64(int bytes) {
    final secure = Random.secure();
    final value = List<int>.generate(bytes, (_) => secure.nextInt(256));
    return base64Encode(value);
  }
}

enum EncryptedVaultStorageErrorCode {
  readFailed,
  writeFailed,
  invalidPayload,
  decryptionFailed,
  secureStorageUnavailable,
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
