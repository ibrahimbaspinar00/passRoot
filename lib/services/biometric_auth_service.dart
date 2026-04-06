import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAuthFailureReason {
  unavailable,
  notEnrolled,
  noCredentials,
  temporaryLockout,
  permanentLockout,
  canceledByUser,
  timedOut,
  systemCanceled,
  authInProgress,
  fallbackRequested,
  noActivity,
  invalidActivity,
  unknown,
}

class BiometricAuthResult {
  const BiometricAuthResult._({required this.success, this.failureReason});

  const BiometricAuthResult.success()
    : this._(success: true, failureReason: null);

  const BiometricAuthResult.failure(BiometricAuthFailureReason reason)
    : this._(success: false, failureReason: reason);

  final bool success;
  final BiometricAuthFailureReason? failureReason;

  bool get shouldFallbackToPrimaryUnlock {
    if (success) {
      return false;
    }
    return switch (failureReason) {
      BiometricAuthFailureReason.canceledByUser => false,
      BiometricAuthFailureReason.systemCanceled => false,
      BiometricAuthFailureReason.authInProgress => false,
      _ => true,
    };
  }
}

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuthentication})
    : _localAuth = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!isSupported && !canCheck) {
        return false;
      }
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    final result = await authenticateDetailed(reason: reason);
    return result.success;
  }

  Future<BiometricAuthResult> authenticateDetailed({
    required String reason,
  }) async {
    final available = await canUseBiometrics();
    if (!available) {
      return const BiometricAuthResult.failure(
        BiometricAuthFailureReason.unavailable,
      );
    }

    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        return const BiometricAuthResult.success();
      }
      return const BiometricAuthResult.failure(
        BiometricAuthFailureReason.canceledByUser,
      );
    } on PlatformException catch (error) {
      return BiometricAuthResult.failure(_mapPlatformCode(error.code));
    } on Exception {
      return const BiometricAuthResult.failure(
        BiometricAuthFailureReason.unknown,
      );
    }
  }

  BiometricAuthFailureReason _mapPlatformCode(String rawCode) {
    final code = rawCode.trim().toLowerCase();
    switch (code) {
      case 'notenrolled':
        return BiometricAuthFailureReason.notEnrolled;
      case 'notavailable':
      case 'biometricnotavailable':
        return BiometricAuthFailureReason.unavailable;
      case 'passcodenotset':
        return BiometricAuthFailureReason.noCredentials;
      case 'lockedout':
        return BiometricAuthFailureReason.temporaryLockout;
      case 'permanentlylockedout':
        return BiometricAuthFailureReason.permanentLockout;
      case 'usercancelled':
      case 'usercanceled':
        return BiometricAuthFailureReason.canceledByUser;
      case 'timeout':
        return BiometricAuthFailureReason.timedOut;
      case 'systemcancelled':
      case 'systemcanceled':
        return BiometricAuthFailureReason.systemCanceled;
      case 'auth_in_progress':
        return BiometricAuthFailureReason.authInProgress;
      case 'userfallback':
        return BiometricAuthFailureReason.fallbackRequested;
      case 'no_activity':
        return BiometricAuthFailureReason.noActivity;
      case 'no_fragment_activity':
        return BiometricAuthFailureReason.invalidActivity;
      default:
        return BiometricAuthFailureReason.unknown;
    }
  }
}
