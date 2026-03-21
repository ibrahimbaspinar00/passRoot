import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class VaultCryptoService {
  static const _algorithmId = 'aes256gcm-pbkdf2-sha256-v1';
  static const _iterations = 210000;

  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  Future<String> encryptString({
    required String plaintext,
    required String passphrase,
  }) async {
    final normalized = passphrase.trim();
    if (normalized.length < 6) {
      throw const VaultCryptoException(
        'Sifreleme anahtari en az 6 karakter olmali.',
      );
    }

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(passphrase: normalized, salt: salt);
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    final envelope = <String, dynamic>{
      'v': 1,
      'alg': _algorithmId,
      'iter': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(envelope);
  }

  Future<String> decryptString({
    required String encryptedPayload,
    required String passphrase,
  }) async {
    final normalized = passphrase.trim();
    if (normalized.length < 6) {
      throw const VaultCryptoException(
        'Sifreleme anahtari en az 6 karakter olmali.',
      );
    }

    late final Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(encryptedPayload);
      if (decoded is! Map<String, dynamic>) {
        throw const VaultCryptoException('Sifreli yedek formati gecersiz.');
      }
      envelope = decoded;
    } on FormatException {
      throw const VaultCryptoException('Sifreli yedek cozumlenemedi.');
    }

    final algorithm = (envelope['alg'] as String?)?.trim();
    if (algorithm != _algorithmId) {
      throw const VaultCryptoException(
        'Bu yedek dosyasi desteklenmeyen bir sifreleme algoritmasi kullaniyor.',
      );
    }

    final salt = _decodeB64(envelope['salt'], 'salt');
    final nonce = _decodeB64(envelope['nonce'], 'nonce');
    final cipherText = _decodeB64(envelope['ciphertext'], 'ciphertext');
    final macBytes = _decodeB64(envelope['mac'], 'mac');
    final key = await _deriveKey(passphrase: normalized, salt: salt);

    try {
      final clearBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const VaultCryptoException(
        'Sifreleme anahtari hatali veya veri bozulmus.',
      );
    }
  }

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
  }) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _decodeB64(dynamic value, String field) {
    final raw = value is String ? value.trim() : '';
    if (raw.isEmpty) {
      throw VaultCryptoException('Sifreli yedekte $field eksik.');
    }
    try {
      return base64Decode(raw);
    } on FormatException {
      throw VaultCryptoException('Sifreli yedekte $field gecersiz.');
    }
  }

  List<int> _randomBytes(int length) {
    final secure = Random.secure();
    return List<int>.generate(length, (_) => secure.nextInt(256));
  }
}

class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}
