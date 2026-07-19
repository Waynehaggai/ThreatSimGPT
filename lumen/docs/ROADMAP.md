# Roadmap

Status legend: ✅ done in the foundation · 🟡 partially scaffolded · ⬜ planned.

## Foundation (this deliverable)

- ✅ Clean Architecture + MVVM skeleton, feature‑first modules
- ✅ Domain model: entities, enums, repository contracts, use cases, service ports
- ✅ `Result`/`Failure` error model
- ✅ Offline‑first sync core: `SyncQueue` (ordering + backoff) & `ConflictResolver`
- ✅ Riverpod DI + GoRouter with auth‑aware redirects
- ✅ Material 3 app theme + 5 reader palettes
- ✅ Runnable guest auth + in‑memory library + reader shell (immersive, mode switch)
- ✅ Future‑ready AI/OCR/TTS/parser/security interfaces
- ✅ Unit tests (sync, conflict resolution, entities, library repo)
- ✅ Full documentation set

## Milestones

### M1 — Persistence & DI hardening
- ✅ Isar collection models for all entities (`data/local/models/`) with indexes
- ✅ Mappers (entity ⇄ model) with deterministic `fastHash` ids for upserts
- ✅ `IsarLibraryRepository`, `IsarAnnotationRepository`,
  `IsarProgressRepository`, `IsarSettingsRepository` (offline-first, reactive,
  sync-enqueueing)
- ✅ Durable `SyncQueueDao` backing store for the offline queue
- ✅ `SecureSecurityService` — biometric/PIN + secure key storage;
  `databaseEncryptionKey()` threaded into DB open (see encryption note below)
- ✅ `HiveCache` for lightweight key/value caching
- ✅ DI bootstrap (`core/di/bootstrap.dart`) with graceful in-memory fallback
- ✅ Tests: library-query matcher, `fastHash`, mapper round-trips (codegen-gated)
- ⬜ Run `build_runner` codegen on a Flutter machine to generate `*.g.dart`
  (models are annotated and generate-ready; see docs/SETUP.md)
- ⬜ Wire remaining presentation (annotation/progress/settings screens) onto the
  new repository providers

> **Encryption note:** Isar 3 (community) has no built‑in at‑rest encryption. On
> device, the DB sits in the OS‑encrypted app sandbox; tokens/keys/PIN hash live
> in the secure enclave via `flutter_secure_storage`. The
> `databaseEncryptionKey()` hook is plumbed through so a SQLCipher‑backed engine
> can be dropped in behind the same interfaces (tracked in M5).

### M2 — Import pipeline
- ⬜ `file_picker` import; copy into app storage; checksum + dedupe
- ⬜ `DocumentParser` impls: PDF (Syncfusion), EPUB (epubx), TXT, DOCX
- ⬜ Metadata + cover extraction; page counts
- 🟡 Format model & dispatch (`DocumentParsingService`) — interfaces done

### M3 — Reading engine
- 🟡 Original Mode PDF renderer (`pdfrx`) into the reader surface
- ⬜ Smart Mode reflow renderer over `BookContent` (paragraphs, images, lists,
  quotes, captions; responsive typography; no zoom/h‑scroll)
- ⬜ Navigation styles: page‑turn, vertical/horizontal scroll, two‑page landscape,
  continuous; page‑turn animations at 60 FPS
- ⬜ TOC, progress/chapter indicators, estimated remaining time, exact resume

### M4 — Annotations, bookmarks, notes, search
- ⬜ Selection toolbar: highlight/underline colors, sticky & free‑text notes
- ⬜ Bookmarks (rename/organize/jump), notes export
- ⬜ Full‑text search: library, in‑book, highlights, notes, authors, collections

### M5 — Security & accessibility
- ⬜ `SecurityService`: biometric/PIN app lock, auto‑lock after inactivity
- ⬜ Screen‑reader semantics, large fonts, high contrast, OpenDyslexic,
  one‑handed / left‑handed layouts, voice navigation

### M6 — Cloud sync (Firebase)
- ⬜ `FirebaseAuthRepository` (email/Google/Apple + anonymous linking)
- ⬜ Firestore/Storage data sources; `FirestoreSyncRepository` driving the engine
- ⬜ Connectivity‑triggered auto‑sync; guest→account migration end‑to‑end
- ⬜ Cross‑device resume prompt UI

### M7 — Text‑to‑speech
- ⬜ `flutter_tts` + `audio_service`: background playback, lock‑screen/Bluetooth
  controls, speed/voice/pitch, sentence highlighting, sleep timer, exact resume

### M8 — OCR
- ⬜ ML Kit `OcrService`: detect image‑only PDFs, run OCR → Smart content,
  user correction UI

### M9 — Statistics & goals
- ⬜ Session tracking → streaks, hours, pages, productive hours, genres
- ⬜ Daily/weekly/monthly goals, yearly summaries, learned reading speed

### M10 — Polish & release
- ⬜ Performance: 2,000+‑page books open fast, 20,000+‑book libraries, lazy
  loading, low memory/battery, 60 FPS
- ⬜ Integration + performance benchmark suites
- ⬜ Store assets, CI/CD, Play Store + App Store submission

## Future (post‑1.0)

Desktop & Web builds · Audiobooks · Family library · Book sharing ·
Collaborative annotations · **AI module** (summaries, explain, dictionary,
translation, Q&A, flashcards, quizzes, mind maps, vocabulary, knowledge graphs,
recommendations — plug into `AiService`) · plugin architecture · reading
challenges · social reading · reading memory timeline.
