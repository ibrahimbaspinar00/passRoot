import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/state/account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _InMemorySecureStorage fakeStorage;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fakeStorage = _InMemorySecureStorage();
  });

  test('AccountStore register, sign out and sign in flow', () async {
    final store = AccountStore(secureStorageService: fakeStorage);
    await store.load();

    expect(store.loaded, isTrue);
    expect(store.isGuest, isTrue);
    expect(store.hasRegisteredAccount, isFalse);

    await store.register(
      username: 'Ibrahim',
      email: 'ibrahim@example.com',
      password: 'Secret#123',
    );

    expect(store.hasRegisteredAccount, isTrue);
    expect(store.isSignedIn, isTrue);
    expect(store.profile?.email, 'ibrahim@example.com');

    await store.signOut();
    expect(store.isSignedIn, isFalse);

    await store.signIn(email: 'ibrahim@example.com', password: 'Secret#123');
    expect(store.isSignedIn, isTrue);
  });

  test('AccountStore profile/security updates work', () async {
    final store = AccountStore(secureStorageService: fakeStorage);
    await store.load();
    await store.register(
      username: 'Aylin',
      email: 'aylin@example.com',
      password: 'Strong#456',
      photoUrl: 'https://example.com/avatar.png',
    );

    await store.updateProfile(
      username: 'Aylin Kara',
      photoUrl: 'https://example.com/new-avatar.png',
    );
    expect(store.profile?.username, 'Aylin Kara');
    expect(store.profile?.photoUrl, 'https://example.com/new-avatar.png');

    await store.changeEmail(
      newEmail: 'aylin.kara@example.com',
      currentPassword: 'Strong#456',
    );
    expect(store.profile?.email, 'aylin.kara@example.com');

    await store.changePassword(
      currentPassword: 'Strong#456',
      newPassword: 'EvenStronger#789',
    );
    await store.signOut();
    await store.signIn(
      email: 'aylin.kara@example.com',
      password: 'EvenStronger#789',
    );
    expect(store.isSignedIn, isTrue);
  });

  test('unauthenticated password reset flow stays disabled', () async {
    final store = AccountStore(secureStorageService: fakeStorage);
    await store.load();
    await store.register(
      username: 'Nehir',
      email: 'nehir@example.com',
      password: 'Strong#456',
    );
    await store.signOut();

    expect(store.supportsUnauthenticatedPasswordReset, isFalse);

    expect(
      () => store.resetPasswordWithEmail(
        email: 'nehir@example.com',
        newPassword: 'Another#789',
      ),
      throwsA(
        isA<AccountOperationException>().having(
          (error) => error.message,
          'message',
          contains('Sifre sifirlama devre disidir'),
        ),
      ),
    );
  });

  test('credential material is not persisted to SharedPreferences', () async {
    final store = AccountStore(secureStorageService: fakeStorage);
    await store.load();
    await store.register(
      username: 'Tester',
      email: 'tester@example.com',
      password: 'Secret#123',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('passroot_account_password_hash_v1'), isNull);
    expect(prefs.getString('passroot_account_password_salt_v1'), isNull);
    expect(prefs.getString('passroot_account_password_iter_v1'), isNull);

    final payload = prefs.getString('passroot_account_state_v1');
    expect(payload, isNotNull);
    final decoded = jsonDecode(payload!) as Map<String, dynamic>;
    expect(decoded.containsKey('passwordHash'), isFalse);
    expect(decoded.containsKey('passwordSalt'), isFalse);
    expect(decoded.containsKey('passwordIterations'), isFalse);
    expect(decoded.containsKey('credentials'), isFalse);
  });

  test(
    'migrates legacy credential material from prefs to secure storage',
    () async {
      const password = 'Legacy#123';
      final salt = List<int>.generate(16, (index) => index + 1);
      final hash = await _hashPassword(
        password: password,
        salt: salt,
        iterations: 210000,
      );
      final hashB64 = base64Encode(hash);
      final saltB64 = base64Encode(salt);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'passroot_account_state_v1': jsonEncode(<String, dynamic>{
          'profile': <String, dynamic>{
            'username': 'Legacy User',
            'email': 'legacy@example.com',
            'createdAtIso': DateTime(2025, 1, 1).toIso8601String(),
            'updatedAtIso': DateTime(2025, 1, 1).toIso8601String(),
          },
          'signedIn': false,
        }),
        'passroot_account_password_hash_v1': hashB64,
        'passroot_account_password_salt_v1': saltB64,
        'passroot_account_password_iter_v1': '210000',
      });

      final store = AccountStore(secureStorageService: fakeStorage);
      await store.load();

      expect(
        await fakeStorage.read('passroot_account_password_hash_v1'),
        hashB64,
      );
      expect(
        await fakeStorage.read('passroot_account_password_salt_v1'),
        saltB64,
      );
      expect(
        await fakeStorage.read('passroot_account_password_iter_v1'),
        '210000',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('passroot_account_password_hash_v1'), isNull);
      expect(prefs.getString('passroot_account_password_salt_v1'), isNull);
      expect(prefs.getString('passroot_account_password_iter_v1'), isNull);

      await store.signIn(email: 'legacy@example.com', password: password);
      expect(store.isSignedIn, isTrue);
    },
  );

  test('surfaces controlled error when secure write fails', () async {
    final store = AccountStore(
      secureStorageService: _FailingWriteSecureStorage(),
    );
    await store.load();

    expect(
      () => store.register(
        username: 'Broken',
        email: 'broken@example.com',
        password: 'Secret#123',
      ),
      throwsA(isA<AccountOperationException>()),
    );

    expect(store.hasRegisteredAccount, isFalse);
    expect(store.isSignedIn, isFalse);
  });
}

Future<List<int>> _hashPassword({
  required String password,
  required List<int> salt,
  required int iterations,
}) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return key.extractBytes();
}

class _InMemorySecureStorage extends SecureStorageService {
  _InMemorySecureStorage() : super(storage: const FlutterSecureStorage());

  final Map<String, String> _memory = <String, String>{};

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }
}

class _FailingWriteSecureStorage extends SecureStorageService {
  _FailingWriteSecureStorage() : super(storage: const FlutterSecureStorage());

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write({required String key, required String value}) async {
    throw Exception('secure write failed');
  }

  @override
  Future<void> delete(String key) async {}
}
