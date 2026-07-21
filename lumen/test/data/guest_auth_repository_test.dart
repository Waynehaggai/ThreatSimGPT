import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/guest_auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

/// Wires a mock [FlutterSecureStorage] to an in-memory map so persistence can be
/// exercised across separate repository instances (i.e. simulated restarts).
_MockStorage _storageBackedBy(Map<String, String> store) {
  final storage = _MockStorage();
  when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
      .thenAnswer((inv) async {
    final key = inv.namedArguments[#key] as String;
    final value = inv.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });
  when(() => storage.read(key: any(named: 'key'))).thenAnswer(
    (inv) async => store[inv.namedArguments[#key] as String],
  );
  when(() => storage.delete(key: any(named: 'key'))).thenAnswer((inv) async {
    store.remove(inv.namedArguments[#key] as String);
  });
  return storage;
}

void main() {
  test('signInAsGuest emits a guest user', () async {
    final repo = GuestAuthRepository(storage: _storageBackedBy({}));
    final result = await repo.signInAsGuest();
    final user = result.valueOrNull!;
    expect(user.isGuest, isTrue);
    expect(user.uid, startsWith('guest-'));
  });

  test('persists the guest session so a restart restores the same uid',
      () async {
    final store = <String, String>{};

    // First "run": sign in as guest.
    final repo1 = GuestAuthRepository(storage: _storageBackedBy(store));
    final user = (await repo1.signInAsGuest()).valueOrNull!;

    // Fresh process: a new instance reading the same persisted storage should
    // restore the session on its first auth-state emission (no login needed).
    final repo2 = GuestAuthRepository(storage: _storageBackedBy(store));
    final restored = await repo2.authStateChanges().first;

    expect(restored, isNotNull);
    expect(restored!.uid, user.uid);
    expect(restored.isGuest, isTrue);
  });

  test('signOut clears the persisted session', () async {
    final store = <String, String>{};
    final repo = GuestAuthRepository(storage: _storageBackedBy(store));
    await repo.signInAsGuest();
    expect(store, isNotEmpty);

    await repo.signOut();

    final repo2 = GuestAuthRepository(storage: _storageBackedBy(store));
    final restored = await repo2.authStateChanges().first;
    expect(restored, isNull);
  });
}
