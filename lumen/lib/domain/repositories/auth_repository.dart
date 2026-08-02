import '../../core/result/result.dart';
import '../entities/user_account.dart';

/// Authentication contract. Supports email/password, Google, Apple, and an
/// anonymous guest mode that is fully functional offline.
abstract interface class AuthRepository {
  /// Emits the current user (guest or authenticated), or `null` if signed out.
  Stream<UserAccount?> authStateChanges();

  UserAccount? get currentUser;

  Future<Result<UserAccount>> signInWithEmail(String email, String password);
  Future<Result<UserAccount>> registerWithEmail(String email, String password);
  Future<Result<UserAccount>> signInWithGoogle();
  Future<Result<UserAccount>> signInWithApple();

  /// Creates (or resumes) an anonymous guest session.
  Future<Result<UserAccount>> signInAsGuest();

  Future<Result<void>> sendPasswordReset(String email);

  /// Links the current anonymous guest to a real credential, preserving the
  /// uid so no data migration copy is required where the backend supports it.
  Future<Result<UserAccount>> upgradeGuest({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();
}
