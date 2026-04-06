import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_logger.dart';

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn, FirebaseAuth? firebaseAuth})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
      _firebaseAuthOverride = firebaseAuth;

  final GoogleSignIn _googleSignIn;
  final FirebaseAuth? _firebaseAuthOverride;

  Future<void>? _initializeFuture;

  FirebaseAuth get _firebaseAuth =>
      _firebaseAuthOverride ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> initialize() {
    final inFlight = _initializeFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final next = _initializeInternal();
    _initializeFuture = next;
    return next.catchError((Object error) {
      _initializeFuture = null;
      throw error;
    });
  }

  Future<void> _initializeInternal() async {
    await _ensureFirebaseInitialized();
    try {
      await _googleSignIn.initialize().timeout(const Duration(seconds: 10));
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'GoogleSignIn.initialize timeout',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'google_initialize'},
      );
      throw const GoogleAuthException(
        'Google giris servisi baslatilirken zaman asimi olustu.',
      );
    } on GoogleSignInException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'GoogleSignIn.initialize failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'google_initialize',
          'google_error_code': error.code.name,
        },
      );
      throw GoogleAuthException(_mapSignInError(error));
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Firebase initialize timeout',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'firebase_initialize'},
      );
      throw const GoogleAuthException(
        'Firebase baslatilirken zaman asimi olustu.',
      );
    } on FirebaseException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Firebase initialize failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'firebase_initialize',
          'firebase_error_code': error.code,
        },
      );
      throw GoogleAuthException(_mapFirebaseInitError(error));
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthService',
        'Firebase initialize failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'firebase_initialize'},
      );
      throw const GoogleAuthException(
        'Firebase baslatilamadi. Google giris su an kullanilamiyor.',
      );
    }
  }

  Future<User?> restoreSession() async {
    await initialize();

    final current = _firebaseAuth.currentUser;
    if (current != null) {
      return current;
    }

    final lightweightAttempt = _googleSignIn.attemptLightweightAuthentication();
    if (lightweightAttempt == null) {
      return null;
    }

    try {
      final account = await lightweightAttempt.timeout(
        const Duration(seconds: 10),
      );
      if (account == null) {
        return null;
      }
      return await _signInFirebaseWithGoogleAccount(account);
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'lightweight authentication timeout',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'restore_session'},
      );
      throw const GoogleAuthException(
        'Google oturum geri yukleme islemi zaman asimina ugradi.',
      );
    } on GoogleSignInException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'lightweight authentication failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'restore_session',
          'google_error_code': error.code.name,
        },
      );
      throw GoogleAuthException(_mapSignInError(error));
    } on FirebaseAuthException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Firebase restore sign-in failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'restore_session',
          'firebase_auth_code': error.code,
        },
      );
      throw GoogleAuthException(_mapFirebaseAuthError(error));
    } on GoogleAuthException {
      rethrow;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthService',
        'unexpected restore error',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'restore_session'},
      );
      throw const GoogleAuthException(
        'Google oturum geri yukleme sirasinda beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<User> signIn() async {
    await initialize();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleAuthException(
        'Bu platformda standart Google giris akisi desteklenmiyor.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final user = await _signInFirebaseWithGoogleAccount(account);
      if (user == null) {
        throw const GoogleAuthException(
          'Google hesabi dogrulandi fakat Firebase oturumu baslatilamadi.',
        );
      }
      return user;
    } on GoogleSignInException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Google sign-in failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'sign_in',
          'google_error_code': error.code.name,
        },
      );
      throw GoogleAuthException(_mapSignInError(error));
    } on FirebaseAuthException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Firebase sign-in failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'sign_in',
          'firebase_auth_code': error.code,
        },
      );
      throw GoogleAuthException(_mapFirebaseAuthError(error));
    } on GoogleAuthException {
      rethrow;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthService',
        'unexpected sign-in error',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'sign_in'},
      );
      throw const GoogleAuthException(
        'Google ile giris sirasinda beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<void> signOut() async {
    await initialize();
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } on GoogleSignInException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Google sign-out failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'sign_out',
          'google_error_code': error.code.name,
        },
      );
      throw GoogleAuthException(_mapSignOutError(error));
    } on FirebaseAuthException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthService',
        'Firebase sign-out failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': 'sign_out',
          'firebase_auth_code': error.code,
        },
      );
      throw GoogleAuthException(_mapFirebaseAuthError(error));
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthService',
        'unexpected sign-out error',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'sign_out'},
      );
      throw const GoogleAuthException(
        'Cikis islemi tamamlanamadi. Tekrar deneyin.',
      );
    }
  }

  Future<User?> _signInFirebaseWithGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    final idToken = account.authentication.idToken?.trim();
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthException(
        'Google kimlik dogrulama belirteci alinamadi. Lutfen tekrar deneyin.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user;
  }

  String _mapFirebaseInitError(FirebaseException error) {
    return switch (error.code) {
      'network-error' => 'Firebase baslatilirken ag baglantisi sorunu olustu.',
      'unknown' => 'Firebase baslatilamadi. Kurulum ayarlarinizi kontrol edin.',
      _ => 'Firebase baslatilamadi. google-services ayarlarinizi kontrol edin.',
    };
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'Bu e-posta farkli bir giris yontemi ile kayitli.';
      case 'invalid-credential':
        return 'Google kimlik bilgisi gecersiz veya suresi dolmus.';
      case 'operation-not-allowed':
        return 'Firebase Console uzerinde Google giris aktif degil.';
      case 'network-request-failed':
        return 'Ag baglantisi hatasi. Internet baglantinizi kontrol edin.';
      case 'too-many-requests':
        return 'Cok fazla deneme yapildi. Lutfen biraz sonra tekrar deneyin.';
      case 'user-disabled':
        return 'Bu hesap devre disi birakilmis.';
      default:
        return 'Kimlik dogrulama sirasinda Firebase hatasi olustu (${error.code}).';
    }
  }

  String _mapSignInError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google girisi iptal edildi.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google giris islemi kesintiye ugradi. Lutfen tekrar deneyin.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google giris ayarlari eksik. Android/iOS/Web konfigurasyonunu kontrol edin.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google giris penceresi acilamadi. Uygulamayi yeniden deneyin.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Secilen Google hesabi aktif oturumla eslesmedi. Tekrar deneyin.';
      default:
        return 'Google ile giris sirasinda beklenmeyen bir hata olustu (${error.code.name}).';
    }
  }

  String _mapSignOutError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google cikis islemi su an tamamlanamadi. Tekrar deneyin.';
      default:
        return 'Cikis islemi tamamlanamadi (${error.code.name}). Tekrar deneyin.';
    }
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
