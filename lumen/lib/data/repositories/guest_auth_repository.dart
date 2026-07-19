import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/user_account.dart';
import '../../domain/repositories/auth_repository.dart';

/// A fully-offline [AuthRepository] implementation covering **guest mode**.
///
/// This ships as the default so the app is usable end-to-end with no Firebase
/// project configured. Cloud sign-in methods return a clear [AuthFailure]
/// until [FirebaseAuthRepository] is wired in via DI (see docs/FIREBASE_SETUP.md).
///
/// Per the spec, guest users get every feature offline; upgrading a guest to a
/// real account preserves their locally-stored uid so data migrates seamlessly.
class GuestAuthRepository implements AuthRepository {
  GuestAuthRepository();

  static const _uuid = Uuid();
  final _controller = StreamController<UserAccount?>.broadcast();
  UserAccount? _current;

  @override
  UserAccount? get currentUser => _current;

  @override
  Stream<UserAccount?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<Result<UserAccount>> signInAsGuest() async {
    final user = _current ??
        UserAccount(
          uid: 'guest-${_uuid.v4()}',
          method: AuthMethod.guest,
          isGuest: true,
          displayName: 'Guest',
          createdAt: DateTime.now(),
        );
    _emit(user);
    return Result.success(user);
  }

  @override
  Future<Result<UserAccount>> upgradeGuest({
    required String email,
    required String password,
  }) async {
    final guest = _current;
    if (guest == null || !guest.isGuest) {
      return const Result.failure(
        AuthFailure('No active guest session to upgrade.'),
      );
    }
    // Preserve the uid so local data maps 1:1 onto the new account.
    final upgraded = guest.copyWith(
      method: AuthMethod.emailPassword,
      email: email,
      isGuest: false,
    );
    _emit(upgraded);
    return Result.success(upgraded);
  }

  @override
  Future<Result<void>> signOut() async {
    _emit(null);
    return const Result.success(null);
  }

  // ── Cloud methods — wired in FirebaseAuthRepository ────────────────────────
  static const _notConfigured = AuthFailure(
    'Cloud accounts require Firebase configuration. See docs/FIREBASE_SETUP.md. '
    'You can continue as a guest — all features work offline.',
  );

  @override
  Future<Result<UserAccount>> signInWithEmail(String e, String p) async =>
      const Result.failure(_notConfigured);
  @override
  Future<Result<UserAccount>> registerWithEmail(String e, String p) async =>
      const Result.failure(_notConfigured);
  @override
  Future<Result<UserAccount>> signInWithGoogle() async =>
      const Result.failure(_notConfigured);
  @override
  Future<Result<UserAccount>> signInWithApple() async =>
      const Result.failure(_notConfigured);
  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Result.failure(_notConfigured);

  void _emit(UserAccount? user) {
    _current = user;
    _controller.add(user);
  }
}
