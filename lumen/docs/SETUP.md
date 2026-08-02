# Setup & build

## Prerequisites

- **Flutter** ≥ 3.24 (stable) with Dart ≥ 3.5 — <https://docs.flutter.dev/get-started/install>
- **Android**: Android Studio + SDK, an emulator or device (minSdk 23)
- **iOS/iPad**: Xcode 15+, CocoaPods, an Apple Developer account for signing
- A recent **Ruby/CocoaPods** for iOS pods

Verify your toolchain:

```bash
flutter doctor
```

## Install & run

```bash
cd lumen
flutter pub get
flutter run                 # launches in offline guest mode
```

No Firebase project is needed to run — the app defaults to offline guest mode
and an in‑memory library. To enable cloud accounts and sync, follow
[`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).

## Code generation

Some production pieces (Isar models, Freezed unions, Riverpod codegen, JSON
serialization) use build_runner. After changing annotated files:

```bash
dart run build_runner build --delete-conflicting-outputs
# or, while iterating:
dart run build_runner watch --delete-conflicting-outputs
```

> The current foundation compiles without codegen — entities are hand‑written
> immutables. Codegen is introduced as the Isar/Freezed models land (roadmap M1).

## Tests

```bash
flutter test                       # unit + widget tests
flutter test test/sync             # a single directory
flutter test --coverage            # writes coverage/lcov.info
```

Integration tests (once added under `integration_test/`):

```bash
flutter test integration_test
```

## Linting & formatting

```bash
dart format .
flutter analyze                    # strict lints via analysis_options.yaml
```

## Fonts

Reading fonts (OpenDyslexic, a Bookerly‑style serif, Merriweather, Georgia) are
loaded from `assets/fonts/`. Drop the licensed `.ttf` files in and declare them
under `flutter: fonts:` in `pubspec.yaml`. Google Fonts (`google_fonts`) can
fetch several of these at runtime for development.

## Android build

```bash
flutter build apk --release          # or:
flutter build appbundle --release    # Play Store
```

Place `android/app/google-services.json` (from Firebase) — git‑ignored.

## iOS build

```bash
cd ios && pod install && cd ..
flutter build ipa --release
```

Place `ios/Runner/GoogleService-Info.plist` (from Firebase) — git‑ignored.
Enable **Sign in with Apple** and **Push** capabilities in Xcode as needed.

## Environment matrix

| Platform | Status |
| --- | --- |
| Android phone/tablet | primary target |
| iPhone / iPad | primary target |
| Windows / macOS / Linux / Web | architecture‑ready (needs Data‑layer adapters) |
