# Firebase configuration

Firebase powers cloud auth and synchronization. It is **optional** — Lumen runs
fully offline in guest mode without it.

## 1. Create the project

1. Go to the [Firebase console](https://console.firebase.google.com) → *Add
   project*.
2. Enable **Authentication**, **Cloud Firestore**, and **Storage**.

## 2. Enable sign‑in providers

Authentication → Sign‑in method → enable:

- **Email/Password**
- **Google**
- **Apple** (also configure Sign in with Apple in the Apple Developer portal and
  Xcode)
- **Anonymous** (backs guest mode / guest linking)

## 3. Register apps & generate options

Use the FlutterFire CLI (recommended):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This creates `lib/firebase_options.dart` and drops
`android/app/google-services.json` + `ios/Runner/GoogleService-Info.plist`.
**All three are git‑ignored** — never commit them.

## 4. Wire it up

In `lib/main.dart`, uncomment the bootstrap and provider overrides:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

runApp(ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(FirebaseAuthRepository(...)),
    // libraryRepositoryProvider.overrideWithValue(IsarLibraryRepository(...)),
    // syncRepositoryProvider.overrideWithValue(FirestoreSyncRepository(...)),
  ],
  child: const LumenApp(),
));
```

The `FirebaseAuthRepository` / Firestore‑backed repositories implement the same
domain interfaces as the defaults, so nothing else changes.

## 5. Security rules

Scope every document to its owner. Starting point for Firestore:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Storage:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## 6. Recommended indexes

Add composite indexes for the common synced queries (Firestore will also prompt
you at runtime): `books` ordered by `lastOpened`/`dateImported`, and
`annotations` filtered by `bookId` + `updatedAt`.

## Cost & privacy notes

- File blobs live in Storage, not Firestore, to keep document reads cheap.
- `book_content` (Smart Mode cache) is **never** uploaded — it is regenerated
  per device, saving storage and bandwidth.
- Consider App Check + Firestore TTL policies before public launch.
