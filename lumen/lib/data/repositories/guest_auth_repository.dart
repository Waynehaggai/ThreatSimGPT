import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  GuestAuthRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _uuid = Uuid();
  static const _kGuestUid = 'lumen.guest.uid';
  static const _kGuestCreated = 'lumen.guest.createdAt';

  final FlutterSecureStorage _storage;
  final _controller = StreamController<UserAccount?>.broadcast();
  UserAccount? _current;
  bool _restored = false;

  @override
  UserAccount? get currentUser => _current;

  @override
  Stream<UserAccount?> authStateChanges() async* {
    // Restore a previously-persisted guest session before the first emission so
    // that a cold start (e.g. Android killing the app while the system file
    // picker is foregrounded) doesn't drop the user back onto the login screen.
    if (!_restored) {
      _restored = true;
      await _restore();
    }
    yield _current;
    yield* _controller.stream;
  }

  /// Re-hydrates [_current] from secure storage. Best-effort: any failure just
  /// leaves the session empty so the user can sign in again.
  Future<void> _restore() async {
    if (_current != null) return;
    try {
      final uid = await _storage.read(key: _kGuestUid);
      if (uid == null || uid.isEmpty) return;
      final createdMs = int.tryParse(
        await _storage.read(key: _kGuestCreated) ?? '',
      );
      _current = UserAccount(
        uid: uid,
        method: AuthMethod.guest,
        isGuest: true,
        displayName: 'Guest',
        createdAt: createdMs != null
            ? DateTime.fromMillisecondsSinceEpoch(createdMs)
            : DateTime.now(),
      );
    } on Object {
      // Ignore; treat as no persisted session.
    }
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
    await _persist(user);
    _emit(user);
    return Result.success(user);
  }

  /// Persists the guest [uid] (and creation time) so the session — and the
  /// local data keyed by that uid — survive an app restart.
  Future<void> _persist(UserAccount user) async {
    try {
      await _storage.write(key: _kGuestUid, value: user.uid);
      await _storage.write(
        key: _kGuestCreated,
        value: (user.createdAt ?? DateTime.now())
            .millisecondsSinceEpoch
            .toString(),
      );
    } on Object {
      // Persistence is best-effort; the session still works for this run.
    }
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
    try {
      await _storage.delete(key: _kGuestUid);
      await _storage.delete(key: _kGuestCreated);
    } on Object {
      // Ignore; the in-memory session is cleared regardless.
    }
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
