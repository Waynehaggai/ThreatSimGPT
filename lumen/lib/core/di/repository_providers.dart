import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/docx_parser.dart';
import '../../data/parsers/document_parsing_service_impl.dart';
import '../../data/parsers/epub_parser.dart';
import '../../data/parsers/pdf_parser.dart';
import '../../data/parsers/plain_text_parser.dart';
import '../../data/repositories/in_memory_annotation_repository.dart';
import '../../data/repositories/in_memory_progress_repository.dart';
import '../../data/repositories/in_memory_statistics_repository.dart';
import '../../data/services/anthropic_ai_service.dart';
import '../../data/services/file_import_service.dart';
import '../../data/services/secure_security_service.dart';
import '../../data/sync/noop_sync_repository.dart';
import '../../domain/entities/reading_stats.dart';
import '../../domain/repositories/annotation_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/services/ai_service.dart';
import '../../domain/services/document_parser.dart';
import '../../domain/services/import_service.dart';
import '../../domain/services/security_service.dart';

/// Repository/service providers that have no lightweight default and are
/// supplied by the production bootstrap (`core/di/bootstrap.dart`).
///
/// This is the standard Riverpod "override‑in‑main" pattern: the default throws
/// so a missing override fails loudly at wire‑up rather than silently doing the
/// wrong thing. Nothing in the default (guest/in‑memory) run path reads these,
/// so the app still launches without persistence configured.

Never _mustOverride(String name) => throw UnimplementedError(
      '$name has no default. Provide it via buildProductionOverrides() in '
      'main.dart (see core/di/bootstrap.dart).',
    );

/// Defaults to the platform-secure implementation (biometric/PIN + secure key
/// storage); the bootstrap provides an already-`init()`-ed instance.
final securityServiceProvider =
    Provider<SecurityService>((ref) => SecureSecurityService());

/// Defaults to an in‑memory implementation so highlights/notes/bookmarks work
/// out of the box; the bootstrap overrides it with `IsarAnnotationRepository`.
final annotationRepositoryProvider =
    Provider<AnnotationRepository>((ref) => InMemoryAnnotationRepository());

/// Defaults to an in‑memory implementation so reader resume/position tracking
/// works out of the box; the bootstrap overrides it with `IsarProgressRepository`.
final progressRepositoryProvider =
    Provider<ProgressRepository>((ref) => InMemoryProgressRepository());

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => _mustOverride('settingsRepositoryProvider'));

/// Document parsing for every supported format. Adding a format is a one-line
/// registration here plus the parser implementation.
final documentParsingServiceProvider = Provider<DocumentParsingService>(
  (ref) => DocumentParsingServiceImpl(const [
    PlainTextParser(),
    EpubParser(),
    PdfParser(),
    DocxParser(),
  ]),
);

/// The import pipeline: checksum → copy into app storage → extract metadata.
final importServiceProvider = Provider<ImportService>(
  (ref) => FileImportService(ref.watch(documentParsingServiceProvider)),
);

/// The synchronization engine. Defaults to inert (offline / no cloud); the
/// bootstrap overrides it with a `SyncEngine` once persistence is available and
/// a Firebase backend is wired.
final syncRepositoryProvider =
    Provider<SyncRepository>((ref) => const NoopSyncRepository());

/// Reactive sync status for the UI (status chip, settings).
final syncStateProvider = StreamProvider<SyncState>(
    (ref) => ref.watch(syncRepositoryProvider).watchState());

/// Reading statistics. Defaults to in-memory; the bootstrap overrides it with
/// `IsarStatisticsRepository`.
final statisticsRepositoryProvider = Provider<StatisticsRepository>(
    (ref) => InMemoryStatisticsRepository());

/// Reactive aggregate stats for the dashboard.
final readingStatsProvider = StreamProvider<ReadingStats>(
    (ref) => ref.watch(statisticsRepositoryProvider).watchStats());

/// AI module configuration. `null` (the default) keeps AI features off. Provide
/// an [AiConfig] pointing at your backend proxy — via a bootstrap override or a
/// `--dart-define`-driven override — to enable them. NEVER embed an API key in
/// the app; the proxy holds the key (see docs/AI_MODULE.md).
final aiConfigProvider = Provider<AiConfig?>((ref) => null);

/// The active [AiService]. Falls back to the no‑op stub until an [AiConfig] is
/// supplied, so nothing breaks when AI is disabled.
final aiServiceProvider = Provider<AiService>((ref) {
  final config = ref.watch(aiConfigProvider);
  if (config == null || !config.enabled) return const DisabledAiService();
  final service = AnthropicAiService(config);
  ref.onDispose(service.dispose);
  return service;
});
