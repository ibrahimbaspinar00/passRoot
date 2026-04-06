import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../security/secure_storage_service.dart';
import 'pin_security_service.dart';

class VaultKeyService {
  VaultKeyService({
    SecureStorageService? secureStorage,
    PinSecurityService? pinSecurityService,
  }) : _secureStorage = secureStorage ?? SecureStorageService(),
       _pinSecurityService = pinSecurityService ?? PinSecurityService();

  static const String _masterWrapKey = 'passroot_vault_dek_master_wrap_v2';
  static const String _pinWrapKey = 'passroot_vault_dek_pin_wrap_v2';
  static const String legacyMasterSecretKey = 'passroot_vault_master_secret_v1';
  static const int _currentEnvelopeVersion = 3;
  static const String _kdfId = 'pbkdf2-sha256';
  static const String _wrapAlgorithmId = 'aes256gcm-wrap-v1';

  static const int _masterIterations = 360000;
  static const int _pinIterations = 260000;

  final SecureStorageService _secureStorage;
  final PinSecurityService _pinSecurityService;
  final AesGcm _cipher = AesGcm.with256bits();

  List<int>? _unlockedDek;

  bool get hasUnlockedDek => _unlockedDek != null && _unlockedDek!.isNotEmpty;

  Future<bool> hasMasterWrap() async {
    final raw = await _secureStorage.read(_masterWrapKey);
    return (raw ?? '').trim().isNotEmpty;
  }

  Future<bool> hasPinWrap() async {
    final raw = await _secureStorage.read(_pinWrapKey);
    return (raw ?? '').trim().isNotEmpty;
  }

  List<int> requireUnlockedDek() {
    final dek = _unlockedDek;
    if (dek == null || dek.isEmpty) {
      throw const VaultKeyException(
        'Kasa anahtari kilitli. Devam etmek icin kilidi acin.',
      );
    }
    return List<int>.from(dek, growable: false);
  }

  Future<void> setupVault({
    required String masterPassword,
    String? optionalPin,
  }) async {
    final normalizedMaster = masterPassword;
    _validateMasterPassword(normalizedMaster);
    if (await hasMasterWrap()) {
      throw const VaultKeyException(
        'Kasa anahtari zaten olusturulmus gorunuyor.',
      );
    }

    final dek = _randomBytes(32);
    final masterWrap = await _buildWrappedDek(
      dek: dek,
      secret: normalizedMaster,
      iterations: _masterIterations,
    );
    await _secureStorage.write(key: _masterWrapKey, value: masterWrap);

    final normalizedPin = (optionalPin ?? '').trim();
    if (normalizedPin.isNotEmpty) {
      if (!_pinSecurityService.isStrongPin(normalizedPin)) {
        throw const VaultKeyException(
          'PIN politikasi gecersiz. 8-12 sayisal veya harf+rakam iceren 8-24 karakter kullanin.',
        );
      }
      await _pinSecurityService.setPin(normalizedPin);
      final pinWrap = await _buildWrappedDek(
        dek: dek,
        secret: normalizedPin,
        iterations: _pinIterations,
      );
      await _secureStorage.write(key: _pinWrapKey, value: pinWrap);
    } else {
      await _pinSecurityService.clearPin();
      await _secureStorage.delete(_pinWrapKey);
    }

    _unlockedDek = dek;
  }

  Future<VaultUnlockResult> unlockWithMasterPasswordDetailed(
    String masterPassword,
  ) async {
    _validateMasterPassword(masterPassword);
    final wrapped = await _secureStorage.read(_masterWrapKey);
    if ((wrapped ?? '').trim().isEmpty) {
      return const VaultUnlockResult.failure(
        reason: VaultUnlockFailureReason.keyMaterialMissing,
        message:
            'Kasa anahtari bulunamadi. Guvenli kurulum tekrar gerekli olabilir.',
      );
    }

    try {
      final unwrapped = await _unwrapDek(
        wrappedEnvelope: wrapped!,
        secret: masterPassword,
      );
      _unlockedDek = unwrapped.dek;
      if (unwrapped.envelopeVersion < _currentEnvelopeVersion) {
        final upgraded = await _buildWrappedDek(
          dek: unwrapped.dek,
          secret: masterPassword,
          iterations: _masterIterations,
        );
        await _secureStorage.write(key: _masterWrapKey, value: upgraded);
      }
      return const VaultUnlockResult.success();
    } on VaultKeyInvalidSecretException {
      return const VaultUnlockResult.failure(
        reason: VaultUnlockFailureReason.invalidSecret,
        message: 'Master password dogrulanamadi.',
      );
    } on VaultKeyMaterialCorruptedException {
      return const VaultUnlockResult.failure(
        reason: VaultUnlockFailureReason.keyMaterialCorrupted,
        message:
            'Kasa kilit materyali bozuk gorunuyor. Guvenli geri yukleme adimini uygulayin.',
      );
    } on VaultKeyException catch (error) {
      return VaultUnlockResult.failure(
        reason: VaultUnlockFailureReason.unknown,
        message: error.message,
      );
    } on Exception {
      return const VaultUnlockResult.failure(
        reason: VaultUnlockFailureReason.unknown,
        message:
            'Master password dogrulamasi sirasinda beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<bool> unlockWithMasterPassword(String masterPassword) async {
    final result = await unlockWithMasterPasswordDetailed(masterPassword);
    return result.success;
  }

  Future<PinVerificationResult> unlockWithPin(String pin) async {
    final pinResult = await _pinSecurityService.verifyPinDetailed(pin);
    if (!pinResult.success) {
      return pinResult;
    }

    final wrapped = await _secureStorage.read(_pinWrapKey);
    if ((wrapped ?? '').trim().isEmpty) {
      return const PinVerificationResult.failure(
        message: 'PIN ile acilacak kasa anahtari bulunamadi.',
      );
    }

    try {
      final normalizedPin = pin.trim();
      final unwrapped = await _unwrapDek(
        wrappedEnvelope: wrapped!,
        secret: normalizedPin,
      );
      _unlockedDek = unwrapped.dek;
      if (unwrapped.envelopeVersion < _currentEnvelopeVersion) {
        final upgraded = await _buildWrappedDek(
          dek: unwrapped.dek,
          secret: normalizedPin,
          iterations: _pinIterations,
        );
        await _secureStorage.write(key: _pinWrapKey, value: upgraded);
      }
      return const PinVerificationResult.success();
    } on VaultKeyMaterialCorruptedException {
      return const PinVerificationResult.failure(
        message:
            'PIN dogrulandi ancak kasa kilit materyali bozuk. Guvenli geri yukleme gerekebilir.',
      );
    } on Exception {
      return const PinVerificationResult.failure(
        message: 'PIN dogrulandi ancak kasa anahtari acilamadi.',
      );
    }
  }

  Future<void> enablePinProtection(String pin) async {
    final normalizedPin = pin.trim();
    if (!_pinSecurityService.isStrongPin(normalizedPin)) {
      throw const VaultKeyException(
        'PIN politikasi gecersiz. 8-12 sayisal veya harf+rakam iceren 8-24 karakter kullanin.',
      );
    }
    final dek = requireUnlockedDek();
    await _pinSecurityService.setPin(normalizedPin);
    final pinWrap = await _buildWrappedDek(
      dek: dek,
      secret: normalizedPin,
      iterations: _pinIterations,
    );
    await _secureStorage.write(key: _pinWrapKey, value: pinWrap);
  }

  Future<void> disablePinProtection() async {
    await _pinSecurityService.clearPin();
    await _secureStorage.delete(_pinWrapKey);
  }

  Future<void> clearAllKeyMaterial() async {
    _unlockedDek = null;
    await _pinSecurityService.clearPin();
    await _secureStorage.delete(_masterWrapKey);
    await _secureStorage.delete(_pinWrapKey);
    await _secureStorage.delete(legacyMasterSecretKey);
  }

  void lockVault() {
    _unlockedDek = null;
  }

  Future<void> deleteLegacyMasterSecret() {
    return _secureStorage.delete(legacyMasterSecretKey);
  }

  Future<String?> readLegacyMasterSecret() {
    return _secureStorage.read(legacyMasterSecretKey);
  }

  void _validateMasterPassword(String value) {
    if (value.trim().isEmpty || value.length < 12) {
      throw const VaultKeyException(
        'Master password en az 12 karakter olmali.',
      );
    }
  }

  Future<String> _buildWrappedDek({
    required List<int> dek,
    required String secret,
    required int iterations,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveSecretKey(
      secret: secret,
      salt: salt,
      iterations: iterations,
    );
    final encrypted = await _cipher.encrypt(dek, secretKey: key, nonce: nonce);
    return jsonEncode(<String, dynamic>{
      'v': _currentEnvelopeVersion,
      'kdf': _kdfId,
      'kdfIter': iterations,
      'salt': base64Encode(salt),
      'wrapAlg': _wrapAlgorithmId,
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
    });
  }

  Future<_UnwrappedDekEnvelope> _unwrapDek({
    required String wrappedEnvelope,
    required String secret,
  }) async {
    final decoded = _decodeEnvelopeMap(wrappedEnvelope);
    final envelopeVersion = _readEnvelopeVersion(decoded);
    final iterations = _readEnvelopeIterations(decoded, envelopeVersion);

    if (envelopeVersion >= 3) {
      final kdf = (decoded['kdf'] as String?)?.trim();
      if (kdf != _kdfId) {
        throw const VaultKeyMaterialCorruptedException(
          'Kasa anahtar zarfinda desteklenmeyen KDF bilgisi var.',
        );
      }
      final wrapAlg = (decoded['wrapAlg'] as String?)?.trim();
      if (wrapAlg != _wrapAlgorithmId) {
        throw const VaultKeyMaterialCorruptedException(
          'Kasa anahtar zarfinda desteklenmeyen wrap algoritmasi var.',
        );
      }
    }

    final salt = _decodeB64(decoded['salt'], field: 'salt');
    final nonce = _decodeB64(decoded['nonce'], field: 'nonce');
    final ciphertext = _decodeB64(decoded['ciphertext'], field: 'ciphertext');
    final mac = _decodeB64(decoded['mac'], field: 'mac');

    final key = await _deriveSecretKey(
      secret: secret,
      salt: salt,
      iterations: iterations,
    );

    try {
      final clear = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      if (clear.length != 32) {
        throw const VaultKeyMaterialCorruptedException(
          'Kasa anahtar uzunlugu gecersiz.',
        );
      }
      return _UnwrappedDekEnvelope(
        dek: clear,
        envelopeVersion: envelopeVersion,
      );
    } on SecretBoxAuthenticationError {
      throw const VaultKeyInvalidSecretException();
    } on VaultKeyMaterialCorruptedException {
      rethrow;
    } on Exception {
      throw const VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarfi cozumlenemedi.',
      );
    }
  }

  Map<String, dynamic> _decodeEnvelopeMap(String wrappedEnvelope) {
    late final Object decoded;
    try {
      decoded = jsonDecode(wrappedEnvelope);
    } on FormatException {
      throw const VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarf formati bozuk.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarf formati gecersiz.',
      );
    }
    return decoded;
  }

  int _readEnvelopeVersion(Map<String, dynamic> decoded) {
    final version = decoded['v'];
    final parsedVersion = version is int ? version : int.tryParse('$version');
    if (parsedVersion == null || parsedVersion < 2) {
      throw const VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarf versiyonu gecersiz.',
      );
    }
    if (parsedVersion > _currentEnvelopeVersion) {
      throw const VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarf versiyonu desteklenmiyor.',
      );
    }
    return parsedVersion;
  }

  int _readEnvelopeIterations(Map<String, dynamic> decoded, int version) {
    final rawIterations = version >= 3 ? decoded['kdfIter'] : decoded['iter'];
    final parsed = rawIterations is int
        ? rawIterations
        : int.tryParse('$rawIterations');
    if (parsed == null || parsed < 100000) {
      throw const VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarf iterasyon bilgisi gecersiz.',
      );
    }
    return parsed;
  }

  Future<SecretKey> _deriveSecretKey({
    required String secret,
    required List<int> salt,
    required int iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
  }

  List<int> _decodeB64(dynamic value, {required String field}) {
    final raw = value is String ? value.trim() : '';
    if (raw.isEmpty) {
      throw VaultKeyException('Kasa anahtar zarfinda $field eksik.');
    }
    try {
      return base64Decode(raw);
    } on FormatException {
      throw VaultKeyMaterialCorruptedException(
        'Kasa anahtar zarfinda $field bozuk.',
      );
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

class VaultKeyException implements Exception {
  const VaultKeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum VaultUnlockFailureReason {
  invalidSecret,
  keyMaterialMissing,
  keyMaterialCorrupted,
  unknown,
}

class VaultUnlockResult {
  const VaultUnlockResult._({
    required this.success,
    required this.reason,
    required this.message,
  });

  const VaultUnlockResult.success()
    : this._(success: true, reason: null, message: null);

  const VaultUnlockResult.failure({
    required VaultUnlockFailureReason reason,
    required String message,
  }) : this._(success: false, reason: reason, message: message);

  final bool success;
  final VaultUnlockFailureReason? reason;
  final String? message;
}

class VaultKeyInvalidSecretException implements Exception {
  const VaultKeyInvalidSecretException();
}

class VaultKeyMaterialCorruptedException implements Exception {
  const VaultKeyMaterialCorruptedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _UnwrappedDekEnvelope {
  const _UnwrappedDekEnvelope({
    required this.dek,
    required this.envelopeVersion,
  });

  final List<int> dek;
  final int envelopeVersion;
}
