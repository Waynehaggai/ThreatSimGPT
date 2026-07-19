import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/services/security_service.dart';

/// Concrete [SecurityService] using the platform secure enclave
/// (`flutter_secure_storage` → Keychain / Keystore) for keys and the PIN hash,
/// and `local_auth` for biometric / device‑credential authentication.
///
/// Call [init] once at startup to hydrate the cached lock method + PIN hash so
/// the synchronous [lockMethod] / [verifyPin] contract can be honoured.
class SecureSecurityService implements SecurityService {
  SecureSecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _kDbKey = 'lumen.db.key';
  static const _kLockMethod = 'lumen.lock.method';
  static const _kPinHash = 'lumen.pin.hash';
  static const _kPinSalt = 'lumen.pin.salt';

  AppLockMethod _cachedMethod = AppLockMethod.none;
  String? _cachedPinHash;
  String? _cachedPinSalt;

  /// Loads cached security state. Safe to call before `runApp`.
  Future<void> init() async {
    final method = await _storage.read(key: _kLockMethod);
    _cachedMethod = AppLockMethod.values.firstWhere(
      (m) => m.name == method,
      orElse: () => AppLockMethod.none,
    );
    _cachedPinHash = await _storage.read(key: _kPinHash);
    _cachedPinSalt = await _storage.read(key: _kPinSalt);
  }

  @override
  AppLockMethod get lockMethod => _cachedMethod;

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } on Object {
      return false;
    }
  }

  @override
  Future<Result<void>> setLockMethod(AppLockMethod method, {String? pin}) async {
    try {
      if (method == AppLockMethod.pin) {
        if (pin == null || pin.length < 4) {
          return const Result.failure(
              ValidationFailure('PIN must be at least 4 digits.'));
        }
        final salt = _randomBytesBase64(16);
        _cachedPinSalt = salt;
        _cachedPinHash = _hashPin(pin, salt);
        await _storage.write(key: _kPinSalt, value: salt);
        await _storage.write(key: _kPinHash, value: _cachedPinHash);
      } else {
        await _storage.delete(key: _kPinHash);
        await _storage.delete(key: _kPinSalt);
        _cachedPinHash = null;
        _cachedPinSalt = null;
      }
      _cachedMethod = method;
      await _storage.write(key: _kLockMethod, value: method.name);
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to set lock method.', cause: e));
    }
  }

  @override
  Future<Result<bool>> authenticate({String reason = 'Unlock Lumen'}) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return Result.success(ok);
    } on Object catch (e) {
      return Result.failure(AuthFailure('Authentication failed.', cause: e));
    }
  }

  @override
  Future<Result<List<int>>> databaseEncryptionKey() async {
    try {
      final existing = await _storage.read(key: _kDbKey);
      if (existing != null) {
        return Result.success(base64Decode(existing));
      }
      final key = _randomBytes(32); // 256-bit
      await _storage.write(key: _kDbKey, value: base64Encode(key));
      return Result.success(key);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to access encryption key.', cause: e));
    }
  }

  @override
  bool verifyPin(String pin) {
    final salt = _cachedPinSalt;
    final hash = _cachedPinHash;
    if (salt == null || hash == null) return false;
    return _hashPin(pin, salt) == hash;
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  String _randomBytesBase64(int length) => base64Encode(_randomBytes(length));
}
