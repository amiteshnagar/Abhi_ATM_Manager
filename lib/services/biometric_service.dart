import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      if (!canAuthenticateWithBiometrics && !isDeviceSupported) {
        return false;
      }
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty || isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Authenticate using biometrics
  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access Abhi ATM Manager',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // fallback to application 4-digit PIN if biometric fails
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
