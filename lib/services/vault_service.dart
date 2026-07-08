import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'vault_crypto_service.dart';
import 'vault_intruder_service.dart';

/// PIN + biometric gate with encryption, lockout, and idle auto-lock.
class VaultService extends ChangeNotifier {
  static const _pinHashKey = 'vault_pin_hash';
  static const _pinSaltKey = 'vault_pin_hash_salt';
  static const _decoyPinHashKey = 'vault_decoy_pin_hash';
  static const _decoySaltKey = 'vault_decoy_pin_salt';
  static const _biometricKey = 'vault_biometric_enabled';
  static const _failedAttemptsKey = 'vault_failed_attempts';
  static const _lockoutUntilKey = 'vault_lockout_until';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();
  final VaultCryptoService crypto = VaultCryptoService();
  final VaultIntruderService intruder = VaultIntruderService();

  bool _unlocked = false;
  bool _decoySession = false;
  DateTime _lastActivity = DateTime.now();
  int _autoLockMinutes = 2;

  bool get isUnlocked => _unlocked && crypto.isUnlocked;
  bool get isDecoySession => _decoySession;

  void configure({required int autoLockMinutes}) {
    _autoLockMinutes = autoLockMinutes;
  }

  void touch() {
    _lastActivity = DateTime.now();
  }

  bool shouldAutoLock() {
    if (!_unlocked) return false;
    if (_autoLockMinutes <= 0) return true;
    return DateTime.now().difference(_lastActivity).inMinutes >= _autoLockMinutes;
  }

  Future<bool> hasPin() async => (await _storage.read(key: _pinHashKey)) != null;

  Future<bool> hasDecoyPin() async => (await _storage.read(key: _decoyPinHashKey)) != null;

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<bool> canUseBiometric() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLockedOut() async {
    final until = await _storage.read(key: _lockoutUntilKey);
    if (until == null) return false;
    final time = DateTime.tryParse(until);
    if (time == null) return false;
    if (DateTime.now().isBefore(time)) return true;
    await _storage.delete(key: _lockoutUntilKey);
    await _storage.write(key: _failedAttemptsKey, value: '0');
    return false;
  }

  Future<Duration?> lockoutRemaining() async {
    final until = await _storage.read(key: _lockoutUntilKey);
    if (until == null) return null;
    final time = DateTime.tryParse(until);
    if (time == null) return null;
    final diff = time.difference(DateTime.now());
    return diff.isNegative ? null : diff;
  }

  Future<void> setPin(String pin) async {
    if (pin.length < 4) throw ArgumentError('PIN must be at least 4 digits');
    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hash(pin, salt));
    await crypto.createMasterKey(pin);
    await _storage.write(key: _failedAttemptsKey, value: '0');
  }

  Future<void> setDecoyPin(String pin) async {
    if (pin.length < 4) throw ArgumentError('PIN must be at least 4 digits');
    final salt = _randomSalt();
    await _storage.write(key: _decoySaltKey, value: salt);
    await _storage.write(key: _decoyPinHashKey, value: _hash(pin, salt));
  }

  Future<void> clearDecoyPin() async {
    await _storage.delete(key: _decoyPinHashKey);
    await _storage.delete(key: _decoySaltKey);
  }

  Future<bool> verifyPin(String pin) async {
    if (await isLockedOut()) return false;

    final stored = await _storage.read(key: _pinHashKey);
    if (stored == null) return false;

    final salt = await _storage.read(key: _pinSaltKey);
    var ok = salt != null ? stored == _hash(pin, salt) : stored == _legacyHash(pin);

    if (ok) {
      if (salt == null) {
        final newSalt = _randomSalt();
        await _storage.write(key: _pinSaltKey, value: newSalt);
        await _storage.write(key: _pinHashKey, value: _hash(pin, newSalt));
      }
      final cryptoOk = await crypto.unlock(pin);
      if (!cryptoOk && await crypto.hasMasterKey()) {
        await _recordFailedAttempt();
        return false;
      }
      if (!await crypto.hasMasterKey()) {
        await crypto.createMasterKey(pin);
      }
      _unlocked = true;
      _decoySession = false;
      _lastActivity = DateTime.now();
      await _storage.write(key: _failedAttemptsKey, value: '0');
      await enableBiometricSession();
      notifyListeners();
      return true;
    }
    await _recordFailedAttempt();
    return false;
  }

  Future<bool> verifyDecoyPin(String pin) async {
    final stored = await _storage.read(key: _decoyPinHashKey);
    final salt = await _storage.read(key: _decoySaltKey);
    if (stored == null || salt == null) return false;
    final ok = stored == _hash(pin, salt);
    if (ok) {
      crypto.lock();
      _unlocked = true;
      _decoySession = true;
      _lastActivity = DateTime.now();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    if (await isLockedOut()) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock secure vault',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return false;

      // Biometric unlock uses cached session if master key was unlocked before in same app session
      // For cold start, user must enter PIN once; after that biometric re-opens session via secure flag
      final pinSession = await _storage.read(key: 'vault_bio_session');
      if (pinSession == 'active' && crypto.isUnlocked) {
        _unlocked = true;
        _decoySession = false;
        _lastActivity = DateTime.now();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Call after successful PIN unlock to allow biometric re-lock bypass within session.
  Future<void> enableBiometricSession() async {
    if (await isBiometricEnabled()) {
      await _storage.write(key: 'vault_bio_session', value: 'active');
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
    if (!enabled) await _storage.delete(key: 'vault_bio_session');
  }

  void lock() {
    _unlocked = false;
    _decoySession = false;
    crypto.lock();
    _storage.delete(key: 'vault_bio_session');
    notifyListeners();
  }

  Future<void> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) throw StateError('Current PIN is incorrect');
    await crypto.changePin(oldPin, newPin);
    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hash(newPin, salt));
  }

  Future<String> readablePath(String path, String itemId) async {
    touch();
    return crypto.readablePath(path, cacheId: itemId);
  }

  Future<void> _recordFailedAttempt() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    final count = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: '$count');
    if (count >= 5) {
      final until = DateTime.now().add(const Duration(seconds: 30));
      await _storage.write(key: _lockoutUntilKey, value: until.toIso8601String());
    }
    await intruder.recordFailedAttempt(count);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  String _legacyHash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  String _randomSalt() {
    final rnd = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }
}
