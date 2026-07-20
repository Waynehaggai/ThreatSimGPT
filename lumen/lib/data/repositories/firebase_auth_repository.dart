import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/user_account.dart';
import '../../domain/repositories/auth_repository.dart';

/// Cloud-backed [AuthRepository] (Firebase Authentication).
///
/// Supports email/password, Google, Apple and anonymous guest mode. Upgrading a
/// guest uses `linkWithCredential`, which **preserves the anonymous uid** — so
/// the user's already-synced data maps 1:1 onto their new account with no copy.
///
/// Firebase is a native plugin; this repository is verified on device. It is
/// wired in via the DI bootstrap once `firebase_options.dart` exists; otherwise
/// the app runs on the offline `GuestAuthRepository`.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;

  @override
  Stream<UserAccount?> authStateChanges() =>
      _auth.authStateChanges().map(_toAccount);

  @override
  UserAccount? get currentUser => _toAccount(_auth.currentUser);

  @override
  Future<Result<UserAccount>> signInWithEmail(String email, String password) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<Result<UserAccount>> registerWithEmail(
    String email,
    String password,
  ) =>
      _guard(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<Result<UserAccount>> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) {
        return const Result.failure(AuthFailure('Google sign-in cancelled.'));
      }
      final auth = await account.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return Result.success(_toAccount(result.user)!);
    } on Object catch (e) {
      return Result.failure(AuthFailure('Google sign-in failed.', cause: e));
    }
  }

  @override
  Future<Result<UserAccount>> signInWithApple() async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final credential = fb.OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      final result = await _auth.signInWithCredential(credential);
      return Result.success(_toAccount(result.user)!);
    } on Object catch (e) {
      return Result.failure(AuthFailure('Apple sign-in failed.', cause: e));
    }
  }

  @override
  Future<Result<UserAccount>> signInAsGuest() =>
      _guard(_auth.signInAnonymously);

  @override
  Future<Result<UserAccount>> upgradeGuest({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      return const Result.failure(
        AuthFailure('No anonymous session to upgrade.'),
      );
    }
    try {
      final credential = fb.EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      // linkWithCredential keeps the same uid → data migrates for free.
      final result = await user.linkWithCredential(credential);
      return Result.success(_toAccount(result.user)!);
    } on Object catch (e) {
      return Result.failure(
        AuthFailure('Could not upgrade account.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        AuthFailure('Could not send reset email.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _google.signOut();
      await _auth.signOut();
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AuthFailure('Sign-out failed.', cause: e));
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  Future<Result<UserAccount>> _guard(
    Future<fb.UserCredential> Function() action,
  ) async {
    try {
      final result = await action();
      return Result.success(_toAccount(result.user)!);
    } on fb.FirebaseAuthException catch (e) {
      return Result.failure(AuthFailure(e.message ?? e.code, cause: e));
    } on Object catch (e) {
      return Result.failure(AuthFailure('Authentication failed.', cause: e));
    }
  }

  UserAccount? _toAccount(fb.User? user) {
    if (user == null) return null;
    return UserAccount(
      uid: user.uid,
      method: _methodOf(user),
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isGuest: user.isAnonymous,
      createdAt: user.metadata.creationTime,
    );
  }

  AuthMethod _methodOf(fb.User user) {
    if (user.isAnonymous) return AuthMethod.guest;
    final providers = user.providerData.map((p) => p.providerId);
    if (providers.contains('google.com')) return AuthMethod.google;
    if (providers.contains('apple.com')) return AuthMethod.apple;
    return AuthMethod.emailPassword;
  }
}
