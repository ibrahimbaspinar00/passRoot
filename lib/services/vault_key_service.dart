import 'dart:convert';
import 'dart:math';

import '../security/secure_storage_service.dart';
import 'pin_security_service.dart';

class VaultKeyService {
  VaultKeyService({
    SecureStorageService? secureStorage,
    PinSecurityService? pinSecurityService,
  }) : _secureStorage = secureStorage ?? SecureStorageService(),
       _pinSecurityService = pinSecurityService ?? PinSecurityService();

  static const String _vaultDekKey = 'passroot_vault_dek_device_v3';
  static const String legacyMasterSecretKey = 'passroot_vault_master_secret_v1';

  final SecureStorageService _secureStorage;
  final PinSecurityService _pinSecurityService;

  List<int>? _unlockedDek;

  bool get hasUnlockedDek => _unlockedDek != null && _unlockedDek!.isNotEmpty;

  Future<bool> hasVaultKeyMaterial() async {
    final raw = await _secureStorage.read(_vaultDekKey);
    return (raw ?? '').trim().isNotEmpty;
  }

  Future<bool> hasPinWrap() => hasVaultKeyMaterial();

  List<int> requireUnlockedDek() {
    final dek = _unlockedDek;
    if (dek == null || dek.isEmpty) {
      throw const VaultKeyException(
        'Kasa anahtari kilitli. Devam etmek icin kilidi acin.',
      );
    }
    return List<int>.from(dek, growable: false);
  }

  Future<void> setupVault({required String pin}) async {
    final normalizedPin = pin.trim();
    if (!_pinSecurityService.isStrongPin(normalizedPin)) {
      throw const VaultKeyException(
        'PIN politikasi gecersiz. PIN 4 veya 6 hane sayisal olmalidir.',
      );
    }

    var dek = await _readDekFromStorage();
    if (dek == null) {
      dek = _randomBytes(32);
      await _secureStorage.write(key: _vaultDekKey, value: base64Encode(dek));
    }

    await _pinSecurityService.setPin(normalizedPin);
    _unlockedDek = dek;
  }

  Future<PinVerificationResult> unlockWithPin(String pin) async {
    final pinResult = await _pinSecurityService.verifyPinDetailed(pin);
    if (!pinResult.success) {
      return pinResult;
    }
    try {
      final dek = await _readDekFromStorage();
      if (dek == null) {
        return const PinVerificationResult.failure(
          message:
              'Kasa anahtari bulunamadi. Kurulum adimini yeniden tamamlayin.',
        );
      }
      _unlockedDek = dek;
      return const PinVerificationResult.success();
    } on VaultKeyException catch (error) {
      return PinVerificationResult.failure(message: error.message);
    } on Exception {
      return const PinVerificationResult.failure(
        message: 'PIN dogrulandi ancak kasa anahtari acilamadi.',
      );
    }
  }

  Future<void> unlockWithBiometricSession() async {
    final dek = await _readDekFromStorage();
    if (dek == null) {
      throw const VaultKeyException(
        'Biyometrik dogrulama basarili ancak kasa anahtari bulunamadi.',
      );
    }
    _unlockedDek = dek;
  }

  Future<void> enablePinProtection(String pin) async {
    final dek = requireUnlockedDek();
    final hasDekInStorage = await hasVaultKeyMaterial();
    if (!hasDekInStorage) {
      await _secureStorage.write(key: _vaultDekKey, value: base64Encode(dek));
    }
    await _pinSecurityService.setPin(pin.trim());
  }

  Future<void> disablePinProtection() async {
    await _pinSecurityService.clearPin();
  }

  Future<void> clearAllKeyMaterial() async {
    _unlockedDek = null;
    await _pinSecurityService.clearPin();
    await _secureStorage.delete(_vaultDekKey);
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

  Future<List<int>?> _readDekFromStorage() async {
    final raw = (await _secureStorage.read(_vaultDekKey))?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = base64Decode(raw);
      if (decoded.length != 32) {
        throw const VaultKeyException('Kasa anahtar uzunlugu gecersiz.');
      }
      return List<int>.from(decoded, growable: false);
    } on FormatException {
      throw const VaultKeyException('Kasa anahtar verisi bozuk.');
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
