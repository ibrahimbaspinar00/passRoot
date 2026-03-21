import 'dart:isolate';

import 'vault_crypto_service.dart';

class VaultCryptoBackgroundService {
  const VaultCryptoBackgroundService();

  Future<String> encryptString({
    required String plaintext,
    required String passphrase,
  }) {
    return Isolate.run<String>(() async {
      final service = VaultCryptoService();
      try {
        return await service.encryptString(
          plaintext: plaintext,
          passphrase: passphrase,
        );
      } on VaultCryptoException catch (error) {
        throw FormatException(error.message);
      }
    });
  }

  Future<String> decryptString({
    required String encryptedPayload,
    required String passphrase,
  }) {
    return Isolate.run<String>(() async {
      final service = VaultCryptoService();
      try {
        return await service.decryptString(
          encryptedPayload: encryptedPayload,
          passphrase: passphrase,
        );
      } on VaultCryptoException catch (error) {
        throw FormatException(error.message);
      }
    });
  }
}
