import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_logger.dart';

enum GoogleAuthFailureType {
  networkError,
  canceled,
  signInFailed,
  invalidConfiguration,
  providerDisabled,
  apiException,
  unknown,
}

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
        type: GoogleAuthFailureType.apiException,
        message: 'Google giris servisi baslatilirken zaman asimi olustu.',
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
      throw _mapSignInError(error);
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
        type: GoogleAuthFailureType.networkError,
        message: 'Firebase baslatilirken zaman asimi olustu.',
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
          'firebase_error_message': error.message,
        },
      );
      throw _mapFirebaseInitError(error);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthService',
        'Firebase initialize failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'firebase_initialize'},
      );
      throw const GoogleAuthException(
        type: GoogleAuthFailureType.invalidConfiguration,
        message:
            'Firebase baslatilamadi. Android icin android/app/google-services.json dosyasini ve Firebase uygulama ayarlarini kontrol edin.',
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
        type: GoogleAuthFailureType.networkError,
        message: 'Google oturum geri yukleme islemi zaman asimina ugradi.',
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
      throw _mapSignInError(error);
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
      throw _mapFirebaseAuthError(error);
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
        type: GoogleAuthFailureType.unknown,
        message:
            'Google oturum geri yukleme sirasinda beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<User> signIn() async {
    await initialize();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleAuthException(
        type: GoogleAuthFailureType.invalidConfiguration,
        message:
            'Bu platformda Google giris akisi desteklenmiyor. Platform konfigürasyonunu kontrol edin.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final user = await _signInFirebaseWithGoogleAccount(account);
      if (user == null) {
        throw const GoogleAuthException(
          type: GoogleAuthFailureType.signInFailed,
          message:
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
      throw _mapSignInError(error);
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
      throw _mapFirebaseAuthError(error);
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
        type: GoogleAuthFailureType.unknown,
        message: 'Google ile giris sirasinda beklenmeyen bir hata olustu.',
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
      throw _mapSignOutError(error);
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
      throw _mapFirebaseAuthError(error);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthService',
        'unexpected sign-out error',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'sign_out'},
      );
      throw const GoogleAuthException(
        type: GoogleAuthFailureType.unknown,
        message: 'Cikis islemi tamamlanamadi. Tekrar deneyin.',
      );
    }
  }

  Future<User?> _signInFirebaseWithGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    final idToken = account.authentication.idToken?.trim();
    if ((idToken ?? '').isEmpty) {
      throw const GoogleAuthException(
        message:
            'Google kimlik belirteci alinamadi. Android package name, SHA-1/SHA-256 ve webClientId ayarlarini kontrol edin.',
        type: GoogleAuthFailureType.invalidConfiguration,
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user;
  }

  GoogleAuthException _mapFirebaseInitError(FirebaseException error) {
    final message = (error.message ?? '').toLowerCase();
    if (error.code == 'network-error') {
      return const GoogleAuthException(
        type: GoogleAuthFailureType.networkError,
        message: 'Firebase baslatilirken ag baglantisi sorunu olustu.',
      );
    }
    if (message.contains('failed to load firebaseoptions') ||
        message.contains('default firebaseapp failed') ||
        message.contains('google_app_id') ||
        message.contains('google-services')) {
      return GoogleAuthException(
        type: GoogleAuthFailureType.invalidConfiguration,
        code: error.code,
        message:
            'Firebase/Google konfigurasyonu gecersiz. Android icin android/app/google-services.json, applicationId (app.passroot.vault), SHA-1/SHA-256 ve Firebase Authentication > Google provider ayarlarini kontrol edin.',
      );
    }
    return GoogleAuthException(
      type: GoogleAuthFailureType.apiException,
      code: error.code,
      message:
          'Firebase baslatilamadi. Konfigürasyonu kontrol edin (google-services.json, package name, SHA fingerprint, provider).',
    );
  }

  GoogleAuthException _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return const GoogleAuthException(
          type: GoogleAuthFailureType.signInFailed,
          message: 'Bu e-posta farkli bir giris yontemi ile kayitli.',
        );
      case 'invalid-credential':
        return const GoogleAuthException(
          type: GoogleAuthFailureType.invalidConfiguration,
          message:
              'Google kimlik bilgisi gecersiz. SHA fingerprint veya client kimligi ayarlarini kontrol edin.',
        );
      case 'operation-not-allowed':
        return const GoogleAuthException(
          type: GoogleAuthFailureType.providerDisabled,
          message: 'Firebase Console uzerinde Google provider aktif degil.',
        );
      case 'network-request-failed':
        return const GoogleAuthException(
          type: GoogleAuthFailureType.networkError,
          message: 'Ag baglantisi hatasi. Internet baglantinizi kontrol edin.',
        );
      case 'too-many-requests':
        return const GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          message:
              'Cok fazla deneme yapildi. Lutfen biraz sonra tekrar deneyin.',
        );
      case 'user-disabled':
        return const GoogleAuthException(
          type: GoogleAuthFailureType.signInFailed,
          message: 'Bu hesap devre disi birakilmis.',
        );
      default:
        return GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          code: error.code,
          message: 'Firebase kimlik dogrulama hatasi olustu (${error.code}).',
        );
    }
  }

  GoogleAuthException _mapSignInError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const GoogleAuthException(
          type: GoogleAuthFailureType.canceled,
          message: 'Google girisi kullanici tarafindan iptal edildi.',
        );
      case GoogleSignInExceptionCode.interrupted:
        return const GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          message:
              'Google giris islemi kesintiye ugradi. Lutfen tekrar deneyin.',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const GoogleAuthException(
          type: GoogleAuthFailureType.invalidConfiguration,
          message:
              'Google konfigurasyonu gecersiz. google-services.json, applicationId, SHA-1/SHA-256 ve webClientId ayarlarini kontrol edin.',
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return const GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          message:
              'Google giris penceresi acilamadi. Uygulamayi yeniden deneyin.',
        );
      case GoogleSignInExceptionCode.userMismatch:
        return const GoogleAuthException(
          type: GoogleAuthFailureType.signInFailed,
          message:
              'Secilen Google hesabi aktif oturumla eslesmedi. Tekrar deneyin.',
        );
      default:
        return GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          code: error.code.name,
          message:
              'Google ile giris sirasinda API hatasi olustu (${error.code.name}).',
        );
    }
  }

  GoogleAuthException _mapSignOutError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.uiUnavailable:
        return const GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          message: 'Google cikis islemi su an tamamlanamadi. Tekrar deneyin.',
        );
      default:
        return GoogleAuthException(
          type: GoogleAuthFailureType.apiException,
          code: error.code.name,
          message:
              'Cikis islemi tamamlanamadi (${error.code.name}). Tekrar deneyin.',
        );
    }
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException({
    required this.type,
    required this.message,
    this.code,
  });

  final GoogleAuthFailureType type;
  final String message;
  final String? code;

  @override
  String toString() => message;
}
