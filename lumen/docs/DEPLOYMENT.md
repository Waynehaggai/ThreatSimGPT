# Deployment & release

How to take Lumen from source to the Google Play Store and Apple App Store.

## 0. Pre-flight

```bash
cd lumen
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.g.dart
dart format .
flutter analyze
flutter test                    # unit + widget + benchmark suites
flutter test integration_test   # on a device/emulator
```

CI runs the same steps on every push touching `lumen/**`
(`.github/workflows/lumen-ci.yml`): format → codegen → analyze → test →
debug APK build.

## 1. Versioning

Bump `version:` in `pubspec.yaml` — `MAJOR.MINOR.PATCH+BUILD`. The build number
after `+` must increase for every store upload.

## 2. Firebase (optional but recommended)

Follow [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) and run `flutterfire configure`.
Enable cloud sync by flipping the bootstrap's remote to
`FirestoreRemoteDataSource` and adding the `FirebaseAuthRepository` override (see
`main.dart`). The app ships and runs fully offline without this.

## 3. Android — Play Store

1. **Signing**: create an upload keystore and a `android/key.properties`
   (git-ignored) referencing it; wire it in `android/app/build.gradle`.
2. **App id / permissions**: set the `applicationId`; the manifest needs
   internet, biometric, and — for background read-aloud — a foreground-service
   media entry (audio_service) and notification permission.
3. **Build**:
   ```bash
   flutter build appbundle --release
   ```
4. Upload `build/app/outputs/bundle/release/app-release.aab` to the Play
   Console. Provide the store listing (see §6), content rating, data-safety form
   (Lumen stores books locally; cloud sync is per-user and encrypted in transit).

`minSdkVersion` 23+ (biometrics, ML Kit).

## 4. iOS / iPad — App Store

1. **Capabilities** (Xcode → Signing & Capabilities): Sign in with Apple, Push
   (if used), Background Modes → Audio (for background TTS), Keychain sharing.
2. **Info.plist** usage strings: `NSFaceIDUsageDescription`,
   `NSPhotoLibraryUsageDescription` (import), microphone not required.
3. **Pods + build**:
   ```bash
   cd ios && pod install && cd ..
   flutter build ipa --release
   ```
4. Upload with Xcode/Transporter; submit in App Store Connect.

## 5. App icons & splash

Generate with `flutter_launcher_icons` + `flutter_native_splash` (add as
dev-dependencies, configure in `pubspec.yaml`, run their generators). Source art
lives in `assets/branding/` (not committed here).

## 6. Store listing (template)

- **Name**: Lumen — Intelligent Reading
- **Subtitle / short**: Read Anything. Anywhere. Forever.
- **Description**: Offline-first reader for PDF, EPUB, DOCX and TXT. Smart
  reflow, highlights & notes, read-aloud, OCR for scans, reading stats, and
  seamless multi-device sync.
- **Keywords**: reader, ebook, pdf, epub, offline, read aloud, annotations
- **Screenshots**: library (grid), Smart reading, reader settings/themes,
  read-aloud, stats dashboard.
- **Privacy**: data stays on device; optional account syncs the user's own
  library/notes/progress, scoped per-user by Firestore rules.

## 7. Release checklist

- [ ] `build_runner` codegen committed clean; `flutter analyze` zero issues
- [ ] All test suites green (incl. `test/performance`)
- [ ] Version + build number bumped
- [ ] Firebase config present & security rules deployed (if cloud enabled)
- [ ] Signing configured (keystore / provisioning profile)
- [ ] Icons, splash, screenshots updated
- [ ] Privacy / data-safety forms completed
- [ ] Smoke-tested a release build on a physical Android and iOS device
