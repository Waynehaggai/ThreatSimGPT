# Architecture

Lumen follows **Clean Architecture** with an **MVVM** presentation layer, wired
together with **Riverpod** for dependency injection and reactive state.

## Layer overview

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation  (features/*/presentation)                      │
│  Widgets ─▶ Riverpod providers (view models) ─▶ Use cases     │
├──────────────────────────────────────────────────────────────┤
│  Domain  (domain/)                                            │
│  Entities · Repository interfaces · Use cases · Service ports │
├──────────────────────────────────────────────────────────────┤
│  Data  (data/)                                               │
│  Repository impls · Local (Isar/Hive) · Remote (Firebase)    │
│  Sync engine · Mappers · Service adapters (OCR/TTS/AI)       │
└──────────────────────────────────────────────────────────────┘
```

**The dependency rule:** source code dependencies point *inward*. Presentation
depends on Domain; Data depends on Domain; **Domain depends on nothing** (pure
Dart, no Flutter/Firebase imports). This is what makes the domain trivially
unit‑testable and the infrastructure swappable.

### Domain layer (`lib/domain`)

The stable core. Framework‑agnostic.

- **Entities** — immutable value objects with `copyWith` and id‑based equality:
  `Book`, `BookContent`/`Chapter`/`ContentBlock`, `ReadingProgress`,
  `Annotation`, `Bookmark`, `Collection`, `ReadingSettings`, `UserAccount`,
  `SyncOperation`, `ReadingStats`.
- **Repository interfaces** — `LibraryRepository`, `AuthRepository`,
  `AnnotationRepository`, `ProgressRepository`, `SettingsRepository`,
  `StatisticsRepository`, `SyncRepository`. Implementations live in Data.
- **Use cases** — single‑responsibility interactors (`ImportBook`,
  `ResolveResumePoint`, `UpgradeGuestAccount`, …) that view models call.
- **Service ports** — future‑ready interfaces: `DocumentParser`/
  `DocumentParsingService`, `OcrService`, `TtsService`, `AiService`,
  `SecurityService`. These are the plug points for AI/OCR/TTS.

### Data layer (`lib/data`)

Implements the domain contracts.

- `local/` — Isar collections (persistence models) + DAOs, Hive caches.
- `remote/` — Firestore/Storage/Auth data sources.
- `repositories/` — repository implementations composing local + remote +
  sync. Default lightweight implementations ship today
  (`InMemoryLibraryRepository`, `GuestAuthRepository`) so the app runs with no
  native/cloud dependencies; production swaps in Isar/Firebase versions via DI.
- `sync/` — the offline‑first engine: `SyncQueue` (ordering + backoff) and
  `ConflictResolver` (newest‑position‑wins, note/highlight merge). Both are pure
  Dart and fully unit‑tested.
- `mappers/` — entity ⇄ persistence/DTO conversions, keeping entities clean.

### Presentation layer (`lib/features`)

**Feature‑first**: each feature (`auth`, `library`, `reader`, `settings`,
`statistics`) owns its `presentation/{providers,screens,widgets}`.

- **View models are Riverpod providers.** `Notifier`/`AsyncNotifier`/
  `StreamProvider` expose immutable UI state; widgets are thin and rebuild
  reactively. No business logic lives in widgets.
- Providers depend on **use cases** (or repositories for simple reads), never on
  Data implementations directly.

## Error handling

No exceptions cross layer boundaries. Data sources throw internal `Exception`s
(`core/error/exceptions.dart`); repositories catch them and return a
`Result<T>` carrying a typed `Failure` (`core/error/failures.dart`). The UI
`fold`s the `Result` into success/error states.

## Dependency injection

Riverpod is the single DI container. Repository/service providers default to the
runnable implementations and are **overridden in `main.dart`** with production
implementations once Firebase/Isar are configured — no call‑site changes needed.

## Offline‑first principle

Every user action writes locally first and returns immediately. A
`SyncOperation` is enqueued for the cloud. The sync engine drains the queue
whenever connectivity allows. See [`SYNC_FLOW.md`](SYNC_FLOW.md).

## Testability

- Domain + sync logic: pure Dart unit tests (no Flutter binding required).
- Repositories: tested against in‑memory implementations and mocked ports.
- View models: tested with `ProviderContainer` overrides.
- Widgets/integration: `flutter_test` + `integration_test`.

## Cross‑platform readiness

Nothing in Domain touches `dart:io`/platform channels directly; platform
concerns (file storage, biometrics, TTS) sit behind service ports. This keeps
the path open to Windows/macOS/Linux/Web with only new Data‑layer adapters.
