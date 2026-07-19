import '../../core/result/result.dart';

/// App-lock mechanism the user has configured.
enum AppLockMethod { none, biometric, pin }

/// Contract for local app security: biometric/PIN lock and the encryption key
/// that protects the local database.
///
/// The concrete implementation uses `local_auth` for Face ID / fingerprint and
/// `flutter_secure_storage` (Keychain / Keystore) for the PIN hash and the
/// database encryption key.
abstract interface class SecurityService {
  Future<bool> isBiometricAvailable();

  AppLockMethod get lockMethod;
  Future<Result<void>> setLockMethod(AppLockMethod method, {String? pin});

  /// Prompts biometric/PIN auth. Returns success only when the user passes.
  Future<Result<bool>> authenticate({String reason = 'Unlock Lumen'});

  /// Retrieves (creating on first run) the symmetric key used to encrypt the
  /// local Isar database at rest. Stored only in the platform secure enclave.
  Future<Result<List<int>>> databaseEncryptionKey();

  bool verifyPin(String pin);
}
