import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAccountService {
  FirebaseAccountService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleInitFuture;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  Stream<User?> userChanges() => _auth.userChanges();

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= _googleSignIn.initialize();
  }

  Future<OAuthCredential> _googleCredential() async {
    try {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw const FirebaseAccountException(
          'Google kimlik dogrulamasi tamamlanamadi (id token bos).',
        );
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (error) {
      throw FirebaseAccountException(_mapGoogleError(error));
    }
  }

  String _mapGoogleError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google giris islemi iptal edildi.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google giris islemi yarida kesildi. Tekrar deneyin.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Sign-In yapilandirma hatasi. Firebase proje ayarlarini ve SHA-1 bilgisini kontrol edin.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google giris arayuzu acilamadi.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google hesap uyusmazligi olustu. Cikis yapip tekrar deneyin.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Google giris sirasinda bilinmeyen bir hata olustu.';
    }
  }

  Future<void> ensureAnonymousUser() async {
    if (_auth.currentUser != null) {
      return;
    }
    await _auth.signInAnonymously();
  }

  Future<UserCredential> linkAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const FirebaseAccountException(
        'Anonim hesap bulunamadi. Once anonim giris yapin.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    return user.linkWithCredential(credential);
  }

  Future<UserCredential> linkAnonymousWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const FirebaseAccountException(
        'Anonim hesap bulunamadi. Once anonim giris yapin.',
      );
    }
    final credential = await _googleCredential();
    return user.linkWithCredential(credential);
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
    }
    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final credential = await _googleCredential();
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Keep sign-out resilient even if Google SDK sign-out fails.
    }
    await _auth.signOut();
  }
}

class FirebaseAccountException implements Exception {
  const FirebaseAccountException(this.message);

  final String message;

  @override
  String toString() => message;
}
