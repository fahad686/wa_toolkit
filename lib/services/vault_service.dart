import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// PIN + biometric gate for the secure vault tab.
class VaultService {
  static const _pinHashKey = 'vault_pin_hash';
  static const _biometricKey = 'vault_biometric_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _unlocked = false;

  bool get isUnlocked => _unlocked;

  Future<bool> hasPin() async => (await _storage.read(key: _pinHashKey)) != null;

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<bool> canUseBiometric() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    if (pin.length < 4) throw ArgumentError('PIN must be at least 4 digits');
    await _storage.write(key: _pinHashKey, value: _hash(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    if (stored == null) return false;
    final ok = stored == _hash(pin);
    if (ok) _unlocked = true;
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock secure vault',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) _unlocked = true;
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  void lock() => _unlocked = false;

  Future<void> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) throw StateError('Current PIN is incorrect');
    await setPin(newPin);
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}
