import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    test('sets and verifies valid pin', () async {
      await service.setPin('1234');

      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('1234'), isTrue);
      expect(await service.verifyPin('4321'), isFalse);
    });

    test('applies lock after repeated failures', () async {
      await service.setPin('1234');

      final first = await service.verifyPinDetailed('9999');
      final second = await service.verifyPinDetailed('9999');
      final third = await service.verifyPinDetailed('9999');

      expect(first.locked, isFalse);
      expect(second.locked, isFalse);
      expect(third.locked, isTrue);
      expect(third.retryAfter, isNot(Duration.zero));
    });

    test('successful verify resets protection counters', () async {
      await service.setPin('1234');
      await service.verifyPinDetailed('9999');
      await service.verifyPinDetailed('9999');

      final success = await service.verifyPinDetailed('1234');
      final nextFailure = await service.verifyPinDetailed('9999');

      expect(success.success, isTrue);
      expect(nextFailure.locked, isFalse);
      expect(nextFailure.failedAttempts, 1);
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
