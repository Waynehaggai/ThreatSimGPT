# Folder structure

```
lumen/
├── lib/
│   ├── main.dart                     # Entry point; ProviderScope + DI overrides
│   ├── app.dart                      # MaterialApp.router, themes
│   │
│   ├── core/                         # Cross-cutting, feature-agnostic code
│   │   ├── constants/                # AppConstants (no Flutter imports)
│   │   ├── di/                       # (reserved) shared provider wiring
│   │   ├── error/                    # Failure (public) + Exception (internal)
│   │   ├── result/                   # Result<T> functional type
│   │   ├── network/                  # Connectivity service
│   │   ├── router/                   # GoRouter config + route constants
│   │   ├── theme/                    # M3 app theme + reader palettes
│   │   └── utils/                    # Logger, helpers
│   │
│   ├── domain/                       # Pure business layer (no framework deps)
│   │   ├── entities/                 # Immutable value objects + enums
│   │   ├── repositories/             # Abstract repository contracts
│   │   ├── usecases/                 # Interactors (one job each)
│   │   └── services/                 # Ports: parser, OCR, TTS, AI, security
│   │
│   ├── data/                         # Implementations of domain contracts
│   │   ├── local/                    # Isar collections + DAOs, Hive caches
│   │   │   ├── models/
│   │   │   └── daos/
│   │   ├── remote/                   # Firebase data sources
│   │   ├── repositories/             # Repository implementations
│   │   ├── sync/                     # SyncQueue + ConflictResolver (pure Dart)
│   │   └── mappers/                  # entity ⇄ model/DTO
│   │
│   └── features/                     # Feature-first presentation modules
│       ├── auth/presentation/{providers,screens,widgets}
│       ├── library/presentation/{providers,screens,widgets}
│       ├── reader/presentation/{providers,screens,widgets}
│       ├── settings/presentation/{providers,screens,widgets}
│       └── statistics/presentation/{providers,screens,widgets}
│
├── test/                             # Mirror of lib/ (unit + widget tests)
│   ├── core/  ├── domain/  ├── data/  └── sync/
│
├── docs/                             # Architecture & operational documentation
├── assets/fonts/                     # Reading fonts (OpenDyslexic, etc.)
├── pubspec.yaml
└── analysis_options.yaml             # Strict lints
```

## Conventions

- **One feature = one folder** under `features/`. A feature never imports
  another feature's `presentation/`; share via `domain/` or `core/`.
- **Providers are the view models.** Screens read providers; they hold no logic.
- **Entities are immutable.** Mutations produce new instances via `copyWith`.
- **Generated files** (`*.g.dart`, `*.freezed.dart`) are git‑ignored and
  produced by `dart run build_runner build`.
- **Naming**: `*_repository.dart` (contracts in domain, `*_repository_impl` or a
  descriptive concrete name in data), `*_usecases.dart`, `*_providers.dart`,
  `*_screen.dart`, `*_tile.dart`/widget‑specific names.
