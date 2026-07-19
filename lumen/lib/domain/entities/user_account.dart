import 'enums.dart';

/// The authenticated (or guest) user.
///
/// Named [UserAccount] to avoid colliding with `firebase_auth`'s `User`. Guest
/// users have [isGuest] `true` and a locally-generated [uid]; on account
/// creation their data is migrated under the new cloud uid (see
/// `MigrateGuestData` use case).
class UserAccount {
  const UserAccount({
    required this.uid,
    required this.method,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isGuest = false,
    this.createdAt,
  });

  final String uid;
  final AuthMethod method;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;
  final DateTime? createdAt;

  bool get isAuthenticated => !isGuest;

  UserAccount copyWith({
    AuthMethod? method,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isGuest,
  }) {
    return UserAccount(
      uid: uid,
      method: method ?? this.method,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) => other is UserAccount && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}
