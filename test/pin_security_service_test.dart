import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passroot/security/secure_storage_service.dart';
import 'package:passroot/services/pin_security_service.dart';

void main() {
  group('PinSecurityService', () {
    late _InMemorySecureStorage fakeStorage;
    late PinSecurityService service;

    setUp(() {
      fakeStorage = _InMemorySecureStorage();
      service = PinSecurityService(secureStorageService: fakeStorage);
    });

    test('sets and verifies valid numeric pin', () async {
      await service.setPin('8273');

      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('8273'), isTrue);
      expect(await service.verifyPin('1111'), isFalse);
    });

    test('supports 6-digit policy', () async {
      await service.setPin('827394');

      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('827394'), isTrue);
      expect(await service.verifyPin('827395'), isFalse);
    });

    test('applies lock after repeated failures', () async {
      await service.setPin('8273');

      final first = await service.verifyPinDetailed('1111');
      final second = await service.verifyPinDetailed('1111');
      final third = await service.verifyPinDetailed('1111');

      expect(first.locked, isFalse);
      expect(second.locked, isFalse);
      expect(third.locked, isTrue);
      expect(third.retryAfter, isNot(Duration.zero));
    });

    test('failed attempts increase lock severity', () async {
      await service.setPin('8273');

      PinVerificationResult result = const PinVerificationResult.failure();
      for (var i = 0; i < 8; i++) {
        result = await service.verifyPinDetailed('1111');
        await fakeStorage.delete('passroot_pin_lock_until_v1');
      }

      expect(result.failedAttempts, 8);
      expect(result.locked, isTrue);
    });

    test('successful verify resets protection counters', () async {
      await service.setPin('8273');
      await service.verifyPinDetailed('1111');
      await service.verifyPinDetailed('1111');

      final success = await service.verifyPinDetailed('8273');
      final nextFailure = await service.verifyPinDetailed('1111');

      expect(success.success, isTrue);
      expect(nextFailure.locked, isFalse);
      expect(nextFailure.failedAttempts, 1);
    });

    test('migrates only policy-compliant 4/6 pin values', () async {
      await service.migrateLegacyPin('8273');
      expect(await service.hasPin(), isTrue);

      await service.clearPin();
      await service.migrateLegacyPin('82739');
      expect(await service.hasPin(), isFalse);
    });
  });
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
