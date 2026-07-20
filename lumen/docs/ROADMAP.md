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
- ✅ `FileImportService`: checksum (SHA‑256) → copy into app storage →
  metadata extraction; injectable dir/clock, unit‑tested
- ✅ Dedupe by content checksum in both repositories (checksum indexed in Isar)
- ✅ `file_picker` multi‑select import wired to the library FAB + empty state
- ✅ `DocumentParser` impls: TXT (done M3), EPUB (epubx), PDF (Syncfusion),
  DOCX (archive + xml); all registered in `DocumentParsingService`
- ✅ HTML→blocks converter (`parseHtmlToBlocks`, pure + tested) shared by EPUB
- ✅ Metadata + page counts; EPUB cover extraction (PNG); image‑only PDF
  detection sets `needsOcr` (feeds M8)
- 🟡 EPUB/PDF/DOCX parsers are native/third‑party‑lib backed — verified on
  device rather than in the pure‑Dart suite
- ⬜ Import progress UI for very large PDFs; PDF cover rasterization (viewer)

### M3 — Reading engine
- ✅ Smart Mode reflow renderer over `BookContent` — `block_renderer` handles
  every `BlockType` (heading, paragraph, image, list, quote, caption, code);
  responsive, no zoom/h‑scroll; typography driven by reading settings
- ✅ `ReaderTypography` — settings + palette → concrete text styles (tested)
- ✅ Working TXT parser (`PlainTextParser`) + `DocumentParsingService` dispatch,
  so `.txt` files are a genuine end‑to‑end read path; sample content otherwise
- ✅ Navigation: continuous/vertical scroll and page‑turn/horizontal via a
  `ReflowPaginator` (`TextPainter` measurement) + pure `PagePacker` (tested)
- ✅ Table of contents sheet with jump‑to‑chapter
- ✅ Progress indicator, current‑chapter tracking, estimated remaining time,
  and **exact resume** (debounced position persistence via `ProgressRepository`)
- 🟡 Original Mode PDF renderer (`pdfrx`) — wired (`OriginalReaderView`);
  native, so verified on device rather than in the pure‑Dart suite
- ⬜ Two‑page landspace layout; polished 60 FPS page‑curl animation
- ⬜ In‑text search + highlight anchoring hookup (lands with M4)

### M4 — Annotations, bookmarks, notes, search
- ✅ Selection toolbar: highlight colours, underline, note, copy — anchored to
  absolute char offsets so annotations survive reflow
- ✅ Highlight/underline rendering over reflowed text (`buildAnnotatedSpan`,
  tested) painted by `BlockView` (selectable `SelectableText.rich`)
- ✅ Free‑text notes on a selection (note dialog); notes export to Markdown
- ✅ Bookmarks: add at current position, list sheet, jump, swipe‑to‑delete
- ✅ Reactive annotation/bookmark providers over `AnnotationRepository`
  (in‑memory default + Isar in production)
- ✅ Global search screen across books (title/author) and highlights/notes,
  wired from the library app bar
- 🟡 In‑book find‑in‑text and rename/organize bookmarks — follow‑ups
- ⬜ Cross‑paragraph selection (SelectableText spans a single block today)

### M5 — Security & accessibility
- ✅ App lock: `AppLockController` + `LockScreen` (biometric / PIN), auto‑lock
  after inactivity via a lifecycle observer (`_LockGate` wraps every page)
- ✅ `shouldAutoLock` timing rule + controller logic **unit‑tested** with a fake
  `SecurityService` (biometric success, PIN verify, grace period)
- ✅ Configure app lock from Settings (biometric / PIN / off; PIN entry)
- ✅ Accessibility: OpenDyslexic toggle, text‑size slider, screen‑reader
  semantics on book tiles (tooltips elsewhere provide labels)
- 🟡 Biometric/secure‑storage are native — verified on device; the lock state
  machine is covered by the pure‑Dart suite
- ⬜ High‑contrast theme, one‑handed / left‑handed layouts, voice navigation;
  bundle the OpenDyslexic/Bookerly font assets

### M6 — Cloud sync (Firebase)
- ✅ `SyncEngine` (`SyncRepository`): drains the durable queue → remote with
  per‑op exponential backoff, pulls + merges, tracks status — decoupled from
  Firebase/local via `RemoteDataSource`/`SyncQueueStore`/`LocalMergeSink`
  interfaces and **unit‑tested with in‑memory fakes**
- ✅ Connectivity‑triggered auto‑sync (flush on regaining network) + opportunistic
  sync on enqueue; sync status surfaced in Settings
- ✅ `FirebaseAuthRepository` (email/Google/Apple + anonymous linking that
  **preserves the uid**, so guest→account migration needs no copy)
- ✅ `FirestoreRemoteDataSource` (Firestore + Storage, per‑user scoped,
  tombstone deletes)
- ✅ Cross‑device resume prompt UI (`ResumePrompt`) wired via `ResolveResumePoint`
  on reader open
- 🟡 Firebase/Firestore/Auth pieces are native‑backed — verified on device; the
  engine orchestration is covered by the pure‑Dart suite
- ⬜ `IsarLocalMergeSink` (apply pulled changes into Isar) + `checkRemoteNewer`
  Firestore query; serialize full entity snapshots into sync payloads
- ⬜ Enable Firebase (`flutterfire configure`) and flip the bootstrap remote from
  no‑op to Firestore

### M7 — Text‑to‑speech
- ✅ Sentence segmenter (`segmentBook`/`splitSentences`, pure + tested) with
  absolute offsets for highlighting + exact‑sentence resume
- ✅ `FlutterTtsService` (`TtsService`): sentence‑by‑sentence speak, play/pause/
  resume/stop, speed, pitch, voice selection, sleep timer
- ✅ `TtsPlaybackController` (unit‑tested with a fake engine): drives the service,
  tracks the current sentence, persists `ttsSentenceIndex` to reading progress
- ✅ Live sentence highlighting in the reader (transient annotation) + read‑aloud
  transport bar (play/pause, stop, speed cycler, sleep timer); headphones button
- ✅ `LumenAudioHandler` (`audio_service`) for background playback + lock‑screen/
  Bluetooth controls (native — verified on device; registered per docs)
- 🟡 flutter_tts / audio_service are native — verified on device; segmentation +
  controller logic covered by the pure‑Dart suite
- ⬜ Auto‑scroll to the spoken sentence; premium AI voices behind `TtsService`

### M8 — OCR
- ✅ `MlKitOcrService` (`OcrService`): image‑only PDF detection (pdfrx text
  probe), per‑page rasterize → ML Kit recognition, **streamed** page results
- ✅ `buildOcrContent` (pure + tested): OCR pages → reflowable `BookContent`
  (paragraphs, page breaks, absolute offsets) + low‑confidence page flagging
- ✅ `OcrRunController` (unit‑tested with a fake engine): runs recognition,
  tracks page progress, aggregates results, builds content
- ✅ OCR review screen: live progress, per‑page **editable correction**, save →
  content becomes readable in Smart Mode and clears `needsOcr`
- ✅ Reader integration: scanned books show a "Run OCR" banner; `readerContent`
  prefers the OCR (corrected) content and now loads real EPUB/PDF/DOCX content
- 🟡 ML Kit + pdfrx rasterization are native — verified on device; the
  content‑builder and controller logic are covered by the pure‑Dart suite
- ⬜ Persist OCR content to Isar across sessions (currently session‑cached)

### M9 — Statistics & goals
- ✅ `applySession` aggregator (pure + tested): streak transitions, hours/pages,
  per‑hour histogram, daily rollover, learned reading speed (EMA), books
  completed, genre totals
- ✅ `StatisticsRepository` impls — in‑memory default + `IsarStatisticsRepository`
  (singleton row, sync‑enqueueing); wired in the bootstrap
- ✅ Automatic session tracking in the reader (duration + pages/words from the
  progress delta, finish detection) folded on close
- ✅ Stats dashboard: books/hours/streak/pages, editable daily goal + progress,
  most‑productive‑hours histogram, reading speed, longest streak
- ⬜ Weekly/monthly/yearly summaries; genre tagging on books (feeds genreMinutes)

### M10 — Polish & release
- ✅ CI/CD: GitHub Actions (`lumen-ci.yml`) — format → codegen → analyze → test
  → debug APK, scoped to `lumen/**`
- ✅ Performance benchmark suite (`test/performance`): 20k‑book query,
  60k‑block pagination, 100k `fastHash`, 5k‑op queue — with timing guardrails
- ✅ Integration smoke test harness (`integration_test/`): boot → guest → library
- ✅ `IsarLocalMergeSink` — applies pulled remote **progress** into Isar via the
  conflict resolver, closing the cloud‑sync pull loop (parser unit‑tested)
- ✅ Deployment guide (`docs/DEPLOYMENT.md`): Android/iOS build, signing, store
  listing, release checklist
- 🟡 Lazy list/grid rendering already via `*.builder`; native Isar‑indexed
  library queries for 20k+ libraries land with the persistence hot‑path pass
- ⬜ Full‑entity sync payloads so annotations/bookmarks/settings also pull‑merge;
  store assets (icons/splash/screenshots) and first submission

## Future (post‑1.0)

### AI module — started
- ✅ `AnthropicAiService` (`AiService`) on Claude `claude-opus-4-8` via the
  Messages API (raw HTTP through a **backend proxy** — no key in the app);
  adaptive thinking for prose, structured outputs for dictionary/flashcards
- ✅ Wired: chapter **summaries** (overflow menu) and selection **Explain /
  Define** (selection toolbar), gated on `aiService.isEnabled`
- ✅ DI gating via `aiConfigProvider` (off by default); unit‑tested with a mock
  HTTP client (see docs/AI_MODULE.md)
- 🟡 `translate`, `answerQuestion`, `generateFlashcards` implemented; UI entry
  points + (for Q&A) passage retrieval/RAG are the next step
- ⬜ Quizzes, mind maps, vocabulary builder, knowledge graphs, recommendations
  (all map onto the same `AiService` interface)

### Other post‑1.0
Desktop & Web builds · Audiobooks · Family library · Book sharing ·
Collaborative annotations · plugin architecture · reading challenges · social
reading · reading memory timeline.
