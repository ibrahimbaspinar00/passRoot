import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../security/secure_storage_service.dart';

class PinSecurityService {
  PinSecurityService({SecureStorageService? secureStorageService})
    : _secureStorage = secureStorageService ?? SecureStorageService();

  static const String _pinHashKey = 'passroot_pin_hash_v1';
  static const String _pinSaltKey = 'passroot_pin_salt_v1';
  static const String _pinIterationsKey = 'passroot_pin_iterations_v1';
  static const String _failedAttemptKey = 'passroot_pin_failed_attempts_v1';
  static const String _lockUntilEpochMsKey = 'passroot_pin_lock_until_v1';

  final SecureStorageService _secureStorage;

  static const int _defaultPbkdf2Iterations = 210000;

  static final RegExp _pinPattern = RegExp(r'^\d{4,8}$');

  bool isValidPin(String pin) => _pinPattern.hasMatch(pin.trim());

  Future<bool> hasPin() async {
    final hash = await _secureStorage.read(_pinHashKey);
    final salt = await _secureStorage.read(_pinSaltKey);
    return (hash ?? '').isNotEmpty && (salt ?? '').isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final normalized = pin.trim();
    if (!isValidPin(normalized)) {
      throw const FormatException('PIN must be 4-8 digits.');
    }

    final salt = _generateSalt(16);
    final hash = await _hashPin(
      normalized,
      salt,
      iterations: _defaultPbkdf2Iterations,
    );
    await _secureStorage.write(key: _pinHashKey, value: base64Encode(hash));
    await _secureStorage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _secureStorage.write(
      key: _pinIterationsKey,
      value: '$_defaultPbkdf2Iterations',
    );
    await resetProtectionState();
  }

  Future<bool> verifyPin(String pin) async {
    final result = await verifyPinDetailed(pin);
    return result.success;
  }

  Future<PinVerificationResult> verifyPinDetailed(String pin) async {
    final normalized = pin.trim();
    if (!isValidPin(normalized)) {
      return const PinVerificationResult.failure(
        message: 'PIN 4-8 rakam olmali.',
      );
    }

    final lockState = await _readLockState();
    if (lockState.isLocked) {
      return PinVerificationResult.locked(
        retryAfter: lockState.retryAfter ?? Duration.zero,
      );
    }

    final encodedHash = await _secureStorage.read(_pinHashKey);
    final encodedSalt = await _secureStorage.read(_pinSaltKey);
    if ((encodedHash ?? '').isEmpty || (encodedSalt ?? '').isEmpty) {
      return const PinVerificationResult.failure(message: 'PIN ayarlanmamis.');
    }

    final expectedHash = base64Decode(encodedHash!);
    final salt = base64Decode(encodedSalt!);
    final iterations = await _readIterations();
    final actualHash = await _hashPin(normalized, salt, iterations: iterations);
    final ok = _constantTimeEquals(expectedHash, actualHash);
    if (ok) {
      await resetProtectionState();
      return const PinVerificationResult.success();
    }

    final protection = await _registerFailedAttempt();
    if (protection.isLocked) {
      return PinVerificationResult.locked(
        retryAfter: protection.retryAfter,
        message: 'Cok fazla hatali deneme.',
      );
    }

    return PinVerificationResult.failure(
      message: 'PIN hatali.',
      failedAttempts: protection.failedAttempts,
    );
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(_pinHashKey);
    await _secureStorage.delete(_pinSaltKey);
    await _secureStorage.delete(_pinIterationsKey);
    await resetProtectionState();
  }

  Future<void> resetProtectionState() async {
    await _secureStorage.delete(_failedAttemptKey);
    await _secureStorage.delete(_lockUntilEpochMsKey);
  }

  Future<void> migrateLegacyPin(String? legacyPin) async {
    final normalized = (legacyPin ?? '').trim();
    if (!isValidPin(normalized)) {
      return;
    }
    if (await hasPin()) {
      return;
    }
    await setPin(normalized);
  }

  Future<List<int>> _hashPin(
    String pin,
    List<int> salt, {
    required int iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<int> _readIterations() async {
    final raw = await _secureStorage.read(_pinIterationsKey);
    final parsed = int.tryParse((raw ?? '').trim());
    if (parsed == null || parsed < 100000) {
      return _defaultPbkdf2Iterations;
    }
    return parsed;
  }

  Future<_PinLockState> _readLockState() async {
    final lockUntilRaw = await _secureStorage.read(_lockUntilEpochMsKey);
    final lockUntilEpoch = int.tryParse((lockUntilRaw ?? '').trim()) ?? 0;
    if (lockUntilEpoch <= 0) {
      return const _PinLockState.unlocked();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockUntilEpoch <= now) {
      await _secureStorage.delete(_lockUntilEpochMsKey);
      return const _PinLockState.unlocked();
    }
    final retryAfter = Duration(milliseconds: lockUntilEpoch - now);
    return _PinLockState.locked(retryAfter: retryAfter);
  }

  Future<_PinAttemptState> _registerFailedAttempt() async {
    final failedRaw = await _secureStorage.read(_failedAttemptKey);
    final previous = int.tryParse((failedRaw ?? '').trim()) ?? 0;
    final nextFailed = previous + 1;
    await _secureStorage.write(key: _failedAttemptKey, value: '$nextFailed');

    final lockDuration = _lockDurationForAttempts(nextFailed);
    if (lockDuration > Duration.zero) {
      final lockUntil = DateTime.now().add(lockDuration).millisecondsSinceEpoch;
      await _secureStorage.write(
        key: _lockUntilEpochMsKey,
        value: '$lockUntil',
      );
      return _PinAttemptState(
        failedAttempts: nextFailed,
        isLocked: true,
        retryAfter: lockDuration,
      );
    }

    return _PinAttemptState(
      failedAttempts: nextFailed,
      isLocked: false,
      retryAfter: Duration.zero,
    );
  }

  Duration _lockDurationForAttempts(int attempts) {
    if (attempts < 3) {
      return Duration.zero;
    }
    if (attempts == 3) {
      return const Duration(seconds: 10);
    }
    if (attempts == 4) {
      return const Duration(seconds: 30);
    }
    if (attempts == 5) {
      return const Duration(minutes: 1);
    }
    if (attempts == 6) {
      return const Duration(minutes: 3);
    }
    return const Duration(minutes: 5);
  }

  List<int> _generateSalt(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < left.length; i++) {
      result |= left[i] ^ right[i];
    }
    return result == 0;
  }
}

class PinVerificationResult {
  const PinVerificationResult._({
    required this.success,
    required this.locked,
    required this.retryAfter,
    required this.failedAttempts,
    required this.message,
  });

  const PinVerificationResult.success()
    : this._(
        success: true,
        locked: false,
        retryAfter: Duration.zero,
        failedAttempts: 0,
        message: null,
      );

  const PinVerificationResult.failure({String? message, int failedAttempts = 0})
    : this._(
        success: false,
        locked: false,
        retryAfter: Duration.zero,
        failedAttempts: failedAttempts,
        message: message,
      );

  const PinVerificationResult.locked({
    required Duration retryAfter,
    String? message,
  }) : this._(
         success: false,
         locked: true,
         retryAfter: retryAfter,
         failedAttempts: 0,
         message: message,
       );

  final bool success;
  final bool locked;
  final Duration retryAfter;
  final int failedAttempts;
  final String? message;

  String retryAfterLabel() {
    final seconds = retryAfter.inSeconds;
    if (seconds <= 0) {
      return '0s';
    }
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = (seconds / 60).ceil();
    return '${minutes}dk';
  }
}

class _PinLockState {
  const _PinLockState._({required this.isLocked, required this.retryAfter});

  const _PinLockState.unlocked() : this._(isLocked: false, retryAfter: null);

  const _PinLockState.locked({required Duration retryAfter})
    : this._(isLocked: true, retryAfter: retryAfter);

  final bool isLocked;
  final Duration? retryAfter;
}

class _PinAttemptState {
  const _PinAttemptState({
    required this.failedAttempts,
    required this.isLocked,
    required this.retryAfter,
  });

  final int failedAttempts;
  final bool isLocked;
  final Duration retryAfter;
}
