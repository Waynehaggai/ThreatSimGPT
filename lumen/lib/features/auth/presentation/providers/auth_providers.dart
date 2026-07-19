import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../../data/repositories/guest_auth_repository.dart';
import '../../../../domain/entities/user_account.dart';
import '../../../../domain/repositories/auth_repository.dart';

/// The active [AuthRepository]. Overridden in `main.dart` with the Firebase
/// implementation once a Firebase project is configured; defaults to the
/// offline guest repository so the app runs out of the box.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = GuestAuthRepository();
  ref.onDispose(() {});
  return repo;
});

/// Reactive authentication state consumed by the router and UI.
final authStateProvider = StreamProvider<UserAccount?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Convenience: the current user synchronously (may be null).
final currentUserProvider = Provider<UserAccount?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Imperative auth actions for the sign-in UI.
final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  AuthController(this._ref);
  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  Future<Result<UserAccount>> continueAsGuest() => _repo.signInAsGuest();
  Future<Result<UserAccount>> signInWithGoogle() => _repo.signInWithGoogle();
  Future<Result<UserAccount>> signInWithApple() => _repo.signInWithApple();
  Future<Result<UserAccount>> signInWithEmail(String email, String password) =>
      _repo.signInWithEmail(email, password);
}
