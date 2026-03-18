import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'PassRoot kilidini acmak icin dogrulayin',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
