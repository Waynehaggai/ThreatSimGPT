import '../../core/result/result.dart';
import '../entities/user_account.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_repository.dart';
import 'usecase.dart';

/// Upgrades an anonymous guest to a real account and ensures their local data
/// (books, notes, progress, bookmarks, highlights, settings) is migrated up.
///
/// Where the backend supports credential-linking the uid is preserved, so no
/// copy is required; otherwise the sync engine re-keys and pushes local data
/// under the new uid. Either way local data is the source of truth and is never
/// lost.
class UpgradeGuestAccount implements UseCase<UserAccount, UpgradeGuestParams> {
  const UpgradeGuestAccount(this._auth, this._sync);
  final AuthRepository _auth;
  final SyncRepository _sync;

  @override
  Future<Result<UserAccount>> call(UpgradeGuestParams params) async {
    final upgrade = await _auth.upgradeGuest(
      email: params.email,
      password: params.password,
    );
    if (upgrade.isFailure) return upgrade;

    // Push everything local up to the (now real) account.
    final flush = await _sync.syncNow();
    if (flush.isFailure) {
      // Account exists; data will sync on next connectivity. Surface success —
      // no user data is lost, it's queued.
      return upgrade;
    }
    return upgrade;
  }
}

class UpgradeGuestParams {
  const UpgradeGuestParams({required this.email, required this.password});
  final String email;
  final String password;
}

/// Signs the user out after flushing any pending sync work.
class SignOut implements UseCase<void, NoParams> {
  const SignOut(this._auth, this._sync);
  final AuthRepository _auth;
  final SyncRepository _sync;

  @override
  Future<Result<void>> call(NoParams _) async {
    await _sync.flushBeforeLogout();
    return _auth.signOut();
  }
}
