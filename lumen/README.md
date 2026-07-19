# Lumen — Intelligent Reading Platform

> **Read Anything. Anywhere. Forever.**

Lumen is an offline-first, cross-platform reading application (Flutter) that
imports PDFs and other book formats into a personal digital library and can
intelligently reflow supported documents into a beautiful, responsive eBook —
while always preserving the original. It is built to grow into a premium
commercial product for the Google Play Store and Apple App Store.

---

## ⚠️ Project status

This directory contains the **Sprint‑0 foundation**: a complete, well‑documented
Clean Architecture skeleton with the core domain model, the offline‑first sync
engine (with real, unit‑tested conflict resolution), routing, theming, a runnable
guest‑mode + in‑memory library slice, future‑ready AI/OCR/TTS interfaces, and the
full documentation set.

It is **not** a finished app. Native‑backed pieces (Isar persistence, Firebase,
PDF/EPUB rendering, OCR, TTS) are defined behind interfaces with default
implementations that let the app compile and run, and are scheduled in
[`docs/ROADMAP.md`](docs/ROADMAP.md). What is implemented vs. planned is called
out explicitly throughout the docs.

> Note: this Flutter project currently lives in the `lumen/` subdirectory of the
> ThreatSimGPT repository (the branch it was scaffolded on). It is self‑contained
> and can be lifted into its own repository at any time.

---

## Highlights

| Area | What's in the foundation |
| --- | --- |
| **Architecture** | Clean Architecture + MVVM, Repository pattern, Riverpod DI, feature‑first modules |
| **Offline‑first** | Local‑first writes, durable sync queue, exponential backoff, deterministic conflict resolution |
| **Reading engine** | Hybrid Original / Smart mode model, reflowable `BookContent`, immersive reader shell |
| **Auth** | Email, Google, Apple + full offline **guest mode**, guest→account upgrade path |
| **Customization** | 5 reader themes, typography/spacing/margins, `ReadingSettings` model |
| **Future‑ready** | AI, OCR, TTS and document‑parser interfaces defined and injectable |
| **Quality** | Unit tests for sync, conflict resolution, entities and the library repo |

## Tech stack

Flutter · Dart 3 · Riverpod · GoRouter · Isar · Hive · Firebase (Auth/Firestore/
Storage) · Google ML Kit OCR · native TTS + `audio_service` · Material 3.

## Quickstart

```bash
cd lumen
flutter pub get
flutter run          # runs in offline guest mode, no Firebase required
flutter test         # runs the unit test suite
```

See [`docs/SETUP.md`](docs/SETUP.md) for full environment setup and
[`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md) to enable cloud sync.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Folder structure](docs/FOLDER_STRUCTURE.md)
- [Database schema](docs/DATABASE_SCHEMA.md)
- [Synchronization flow](docs/SYNC_FLOW.md)
- [Setup](docs/SETUP.md) · [Firebase setup](docs/FIREBASE_SETUP.md)
- [Roadmap](docs/ROADMAP.md)
