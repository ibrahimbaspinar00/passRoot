import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../security/secure_storage_service.dart';

enum PinSecretMode { numeric, alphanumeric }

extension PinSecretModeStorage on PinSecretMode {
  String get storageValue {
    switch (this) {
      case PinSecretMode.numeric:
        return 'numeric';
      case PinSecretMode.alphanumeric:
        return 'alphanumeric';
    }
  }

  static PinSecretMode? parse(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'numeric':
        return PinSecretMode.numeric;
      case 'alphanumeric':
        return PinSecretMode.alphanumeric;
      default:
        return null;
    }
  }
}

class PinSecurityService {
  PinSecurityService({SecureStorageService? secureStorageService})
    : _secureStorage = secureStorageService ?? SecureStorageService();

  static const String _pinHashKey = 'passroot_pin_hash_v1';
  static const String _pinSaltKey = 'passroot_pin_salt_v1';
  static const String _pinIterationsKey = 'passroot_pin_iterations_v1';
  static const String _failedAttemptKey = 'passroot_pin_failed_attempts_v1';
  static const String _lockUntilEpochMsKey = 'passroot_pin_lock_until_v1';
  static const String _pinModeKey = 'passroot_pin_mode_v2';
  static const String _pinPolicyVersionKey = 'passroot_pin_policy_version_v2';

  final SecureStorageService _secureStorage;

  static const int _defaultPbkdf2Iterations = 260000;
  static const int _minimumPbkdf2Iterations = 120000;
  static const int _legacyPolicyVersion = 1;
  static const int _currentPolicyVersion = 3;

  static const int legacyMinNumericPinLength = 6;
  static const int legacyMaxNumericPinLength = 12;
  static const int minNumericPinLength = 4;
  static const int maxNumericPinLength = 6;
  static const int minAlphanumericLength = 8;
  static const int maxAlphanumericLength = 24;
  static const int maxPinLength = maxNumericPinLength;

  static final RegExp _currentNumericPinPattern = RegExp(r'^(\d{4}|\d{6})$');
  static final RegExp _legacyNumericPinPattern = RegExp(
    '^\\d{$legacyMinNumericPinLength,$legacyMaxNumericPinLength}\$',
  );
  static final RegExp _legacyAlphanumericAllowedPattern = RegExp(
    '^[A-Za-z\\d]{$minAlphanumericLength,$maxAlphanumericLength}\$',
  );
  static final RegExp _potentialUnlockInputPattern = RegExp(
    '^[A-Za-z\\d]{4,$maxAlphanumericLength}\$',
  );
  static final RegExp _letterPattern = RegExp(r'[A-Za-z]');
  static final RegExp _digitPattern = RegExp(r'\d');
  static final RegExp _repeatedDoublePattern = RegExp(r'^(\d\d)\1+$');

  bool isValidPin(String pin) => isStrongPin(pin);

  bool isStrongPin(String pin) => isStrongPinCandidate(pin);

  static PinSecretMode inferMode(String pin) {
    final normalized = pin.trim();
    final numericOnly = RegExp(r'^\d+$').hasMatch(normalized);
    return numericOnly ? PinSecretMode.numeric : PinSecretMode.alphanumeric;
  }

  static bool isPotentialUnlockInput(String pin) {
    final normalized = pin.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _potentialUnlockInputPattern.hasMatch(normalized);
  }

  static bool isStrongPinCandidate(String pin) {
    final normalized = pin.trim();
    if (!_currentNumericPinPattern.hasMatch(normalized)) {
      return false;
    }
    return !_isWeakNumericPinPattern(normalized);
  }

  static String enrollmentPolicyLabelTr() {
    return 'PIN sadece 4 veya 6 hane sayisal olmalidir.';
  }

  static String enrollmentPolicyLabelEn() {
    return 'PIN must be numeric and exactly 4 or 6 digits.';
  }

  Future<bool> hasPin() async {
    final hash = await _secureStorage.read(_pinHashKey);
    final salt = await _secureStorage.read(_pinSaltKey);
    return (hash ?? '').isNotEmpty && (salt ?? '').isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final normalized = pin.trim();
    if (!isStrongPinCandidate(normalized)) {
      throw const FormatException(
        'PIN policy mismatch. PIN must be numeric and exactly 4 or 6 digits.',
      );
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
    await _secureStorage.write(
      key: _pinModeKey,
      value: PinSecretMode.numeric.storageValue,
    );
    await _secureStorage.write(
      key: _pinPolicyVersionKey,
      value: '$_currentPolicyVersion',
    );
    await resetProtectionState();
  }

  Future<bool> verifyPin(String pin) async {
    final result = await verifyPinDetailed(pin);
    return result.success;
  }

  Future<PinVerificationResult> verifyPinDetailed(String pin) async {
    final normalized = pin.trim();
    if (!isPotentialUnlockInput(normalized)) {
      return const PinVerificationResult.failure(
        message: 'PIN formati gecersiz.',
      );
    }

    final lockState = await _readLockState();
    if (lockState.isLocked) {
      return PinVerificationResult.locked(
        retryAfter: lockState.retryAfter ?? Duration.zero,
        failedAttempts: lockState.failedAttempts,
      );
    }

    final encodedHash = await _secureStorage.read(_pinHashKey);
    final encodedSalt = await _secureStorage.read(_pinSaltKey);
    if ((encodedHash ?? '').isEmpty || (encodedSalt ?? '').isEmpty) {
      return const PinVerificationResult.failure(message: 'PIN ayarlanmamis.');
    }

    final policy = await _readStoredPolicy();
    if (!_matchesStoredPolicyFormat(normalized, policy)) {
      return const PinVerificationResult.failure(
        message: 'PIN tanimli politika ile uyusmuyor.',
      );
    }

    final expectedHash = base64Decode(encodedHash!);
    final salt = base64Decode(encodedSalt!);
    final iterations = await _readIterations();
    final actualHash = await _hashPin(normalized, salt, iterations: iterations);
    final ok = _constantTimeEquals(expectedHash, actualHash);
    if (ok) {
      await resetProtectionState();
      await _upgradePolicyMetadataIfEligible(
        pin: normalized,
        currentPolicy: policy,
      );
      return const PinVerificationResult.success();
    }

    final protection = await _registerFailedAttempt();
    if (protection.isLocked) {
      return PinVerificationResult.locked(
        retryAfter: protection.retryAfter,
        failedAttempts: protection.failedAttempts,
        message:
            'Cok fazla deneme yapildi. ${PinVerificationResult._label(protection.retryAfter)} sonra tekrar deneyin.',
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
    await _secureStorage.delete(_pinModeKey);
    await _secureStorage.delete(_pinPolicyVersionKey);
    await resetProtectionState();
  }

  Future<void> resetProtectionState() async {
    await _secureStorage.delete(_failedAttemptKey);
    await _secureStorage.delete(_lockUntilEpochMsKey);
  }

  Future<void> migrateLegacyPin(String? legacyPin) async {
    final normalized = (legacyPin ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!isStrongPinCandidate(normalized)) {
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
    if (parsed == null || parsed < _minimumPbkdf2Iterations) {
      return _defaultPbkdf2Iterations;
    }
    return parsed;
  }

  Future<_StoredPinPolicy> _readStoredPolicy() async {
    final rawVersion = await _secureStorage.read(_pinPolicyVersionKey);
    final parsedVersion = int.tryParse((rawVersion ?? '').trim());
    final rawMode = await _secureStorage.read(_pinModeKey);
    final parsedMode = PinSecretModeStorage.parse(rawMode);

    if (parsedVersion == null || parsedMode == null) {
      return const _StoredPinPolicy.legacyNumeric();
    }

    return _StoredPinPolicy(
      version: parsedVersion,
      mode: parsedMode,
      legacyFormatAllowed: parsedVersion < _currentPolicyVersion,
    );
  }

  bool _matchesStoredPolicyFormat(String pin, _StoredPinPolicy policy) {
    if (policy.version >= _currentPolicyVersion) {
      return _currentNumericPinPattern.hasMatch(pin);
    }

    if (policy.mode == PinSecretMode.numeric) {
      return _legacyNumericPinPattern.hasMatch(pin);
    }

    return _legacyAlphanumericAllowedPattern.hasMatch(pin) &&
        _letterPattern.hasMatch(pin) &&
        _digitPattern.hasMatch(pin);
  }

  Future<void> _upgradePolicyMetadataIfEligible({
    required String pin,
    required _StoredPinPolicy currentPolicy,
  }) async {
    if (!currentPolicy.legacyFormatAllowed) {
      return;
    }
    if (!isStrongPinCandidate(pin)) {
      return;
    }
    await _secureStorage.write(
      key: _pinModeKey,
      value: PinSecretMode.numeric.storageValue,
    );
    await _secureStorage.write(
      key: _pinPolicyVersionKey,
      value: '$_currentPolicyVersion',
    );
  }

  Future<_PinLockState> _readLockState() async {
    final lockUntilRaw = await _secureStorage.read(_lockUntilEpochMsKey);
    final lockUntilEpoch = int.tryParse((lockUntilRaw ?? '').trim()) ?? 0;
    final failedAttempts = await _readFailedAttemptCount();
    if (lockUntilEpoch <= 0) {
      return _PinLockState.unlocked(failedAttempts: failedAttempts);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockUntilEpoch <= now) {
      await _secureStorage.delete(_lockUntilEpochMsKey);
      return _PinLockState.unlocked(failedAttempts: failedAttempts);
    }
    final retryAfter = Duration(milliseconds: lockUntilEpoch - now);
    return _PinLockState.locked(
      retryAfter: retryAfter,
      failedAttempts: failedAttempts,
    );
  }

  Future<int> _readFailedAttemptCount() async {
    final failedRaw = await _secureStorage.read(_failedAttemptKey);
    return int.tryParse((failedRaw ?? '').trim()) ?? 0;
  }

  Future<_PinAttemptState> _registerFailedAttempt() async {
    final previous = await _readFailedAttemptCount();
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
      return const Duration(seconds: 30);
    }
    if (attempts == 4) {
      return const Duration(minutes: 2);
    }
    if (attempts == 5) {
      return const Duration(minutes: 10);
    }
    if (attempts == 6) {
      return const Duration(minutes: 30);
    }
    if (attempts == 7) {
      return const Duration(hours: 2);
    }
    if (attempts == 8) {
      return const Duration(hours: 8);
    }
    if (attempts == 9) {
      return const Duration(hours: 24);
    }
    return const Duration(hours: 48);
  }

  static bool _isWeakNumericPinPattern(String pin) {
    if (pin.isEmpty) {
      return true;
    }
    final first = pin.codeUnitAt(0);
    final allSame = pin.codeUnits.every((unit) => unit == first);
    if (allSame) {
      return true;
    }

    const ascending = '012345678901234567890';
    const descending = '987654321098765432109';
    if (ascending.contains(pin) || descending.contains(pin)) {
      return true;
    }

    if (_repeatedDoublePattern.hasMatch(pin)) {
      return true;
    }

    return false;
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
    int failedAttempts = 0,
  }) : this._(
         success: false,
         locked: true,
         retryAfter: retryAfter,
         failedAttempts: failedAttempts,
         message: message,
       );

  final bool success;
  final bool locked;
  final Duration retryAfter;
  final int failedAttempts;
  final String? message;

  String retryAfterLabel() => _label(retryAfter);

  static String _label(Duration retryAfter) {
    final seconds = retryAfter.inSeconds;
    if (seconds <= 0) {
      return '0s';
    }
    if (seconds < 60) {
      return '${seconds}s';
    }
    if (seconds < 3600) {
      final minutes = (seconds / 60).ceil();
      return '${minutes}dk';
    }
    if (seconds < 86400) {
      final hours = (seconds / 3600).ceil();
      return '${hours}s';
    }
    final days = (seconds / 86400).ceil();
    return '${days}g';
  }
}

class _PinLockState {
  const _PinLockState._({
    required this.isLocked,
    required this.retryAfter,
    required this.failedAttempts,
  });

  const _PinLockState.unlocked({required int failedAttempts})
    : this._(isLocked: false, retryAfter: null, failedAttempts: failedAttempts);

  const _PinLockState.locked({
    required Duration retryAfter,
    required int failedAttempts,
  }) : this._(
         isLocked: true,
         retryAfter: retryAfter,
         failedAttempts: failedAttempts,
       );

  final bool isLocked;
  final Duration? retryAfter;
  final int failedAttempts;
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

class _StoredPinPolicy {
  const _StoredPinPolicy({
    required this.version,
    required this.mode,
    required this.legacyFormatAllowed,
  });

  const _StoredPinPolicy.legacyNumeric()
    : this(
        version: PinSecurityService._legacyPolicyVersion,
        mode: PinSecretMode.numeric,
        legacyFormatAllowed: true,
      );

  final int version;
  final PinSecretMode mode;
  final bool legacyFormatAllowed;
}
