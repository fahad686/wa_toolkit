import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// AES file encryption for vault media. Master key is stored encrypted in secure storage.
class VaultCryptoService {
  static const _masterKeyKey = 'vault_master_key_enc';
  static const _saltKey = 'vault_pin_salt';
  static const _encExt = '.enc';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  enc.Key? _sessionKey;
  final Map<String, String> _tempPaths = {};

  bool get isUnlocked => _sessionKey != null;

  static bool isEncryptedPath(String path) => path.endsWith(_encExt);

  Future<void> createMasterKey(String pin) async {
    final salt = _randomSalt();
    await _storage.write(key: _saltKey, value: salt);
    final session = enc.Key.fromSecureRandom(32);
    final wrapped = _wrapKey(session, pin, salt);
    await _storage.write(key: _masterKeyKey, value: wrapped);
    _sessionKey = session;
  }

  Future<bool> unlock(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final wrapped = await _storage.read(key: _masterKeyKey);
    if (salt == null || wrapped == null) return false;
    try {
      _sessionKey = _unwrapKey(wrapped, pin, salt);
      return true;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    _sessionKey = null;
    for (final temp in _tempPaths.values) {
      try {
        File(temp).deleteSync();
      } catch (_) {}
    }
    _tempPaths.clear();
  }

  Future<bool> hasMasterKey() async => (await _storage.read(key: _masterKeyKey)) != null;

  Future<void> changePin(String oldPin, String newPin) async {
    if (!await unlock(oldPin)) throw StateError('Current PIN is incorrect');
    final salt = await _storage.read(key: _saltKey) ?? _randomSalt();
    await _storage.write(key: _saltKey, value: salt);
    final wrapped = _wrapKey(_sessionKey!, newPin, salt);
    await _storage.write(key: _masterKeyKey, value: wrapped);
  }

  Future<String> encryptFile(String plainPath, {String? destPath}) async {
    final key = _sessionKey;
    if (key == null) throw StateError('Vault is locked');

    final source = File(plainPath);
    if (!await source.exists()) throw StateError('File not found');

    final target = destPath ?? '$plainPath$_encExt';
    final bytes = await source.readAsBytes();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final out = BytesBuilder();
    out.add(iv.bytes);
    out.add(encrypted.bytes);
    await File(target).writeAsBytes(out.toBytes());

    if (target != plainPath && plainPath != target) {
      await source.delete();
    }
    return target;
  }

  Future<String> readablePath(String path, {required String cacheId}) async {
    if (!isEncryptedPath(path)) return path;

    final key = _sessionKey;
    if (key == null) throw StateError('Vault is locked');

    if (_tempPaths.containsKey(cacheId)) {
      final existing = _tempPaths[cacheId]!;
      if (File(existing).existsSync()) return existing;
    }

    final file = File(path);
    final raw = await file.readAsBytes();
    if (raw.length < 17) throw StateError('Corrupt vault file');

    final iv = enc.IV(Uint8List.fromList(raw.sublist(0, 16)));
    final cipher = enc.Encrypted(Uint8List.fromList(raw.sublist(16)));
    final encrypter = enc.Encrypter(enc.AES(key));
    final plain = encrypter.decryptBytes(cipher, iv: iv);

    final tempDir = Directory(p.join(Directory.systemTemp.path, 'wa_vault'));
    if (!await tempDir.exists()) await tempDir.create(recursive: true);
    final ext = p.extension(path.replaceAll(_encExt, ''));
    final tempPath = p.join(tempDir.path, '$cacheId$ext');
    await File(tempPath).writeAsBytes(plain);
    _tempPaths[cacheId] = tempPath;
    return tempPath;
  }

  String _wrapKey(enc.Key key, String pin, String salt) {
    final derived = _deriveKeyBytes(pin, salt);
    final iv = enc.IV.fromSecureRandom(16);
    final wrapper = enc.Encrypter(enc.AES(enc.Key(derived)));
    final encrypted = wrapper.encrypt(key.base64, iv: iv);
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  enc.Key _unwrapKey(String wrapped, String pin, String salt) {
    final parts = wrapped.split(':');
    if (parts.length != 2) throw StateError('Invalid vault key');
    final derived = _deriveKeyBytes(pin, salt);
    final iv = enc.IV.fromBase64(parts[0]);
    final wrapper = enc.Encrypter(enc.AES(enc.Key(derived)));
    final keyB64 = wrapper.decrypt64(parts[1], iv: iv);
    return enc.Key.fromBase64(keyB64);
  }

  Uint8List _deriveKeyBytes(String pin, String salt) {
    var bytes = Uint8List.fromList(utf8.encode('$salt::$pin'));
    for (var i = 0; i < 12000; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return bytes;
  }

  String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Encode(bytes);
  }
}
