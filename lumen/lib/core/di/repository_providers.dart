import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/document_parsing_service_impl.dart';
import '../../data/parsers/plain_text_parser.dart';
import '../../data/repositories/in_memory_progress_repository.dart';
import '../../domain/repositories/annotation_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/ai_service.dart';
import '../../domain/services/document_parser.dart';
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

final securityServiceProvider = Provider<SecurityService>(
    (ref) => _mustOverride('securityServiceProvider'));

final annotationRepositoryProvider = Provider<AnnotationRepository>(
    (ref) => _mustOverride('annotationRepositoryProvider'));

/// Defaults to an in‑memory implementation so reader resume/position tracking
/// works out of the box; the bootstrap overrides it with `IsarProgressRepository`.
final progressRepositoryProvider =
    Provider<ProgressRepository>((ref) => InMemoryProgressRepository());

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => _mustOverride('settingsRepositoryProvider'));

/// Document parsing (TXT works today; PDF/EPUB/DOCX register in M2).
final documentParsingServiceProvider = Provider<DocumentParsingService>(
  (ref) => DocumentParsingServiceImpl(const [PlainTextParser()]),
);

/// AI features default to the no‑op stub; swap in a real provider when an AI
/// backend is configured (ROADMAP: Future).
final aiServiceProvider = Provider<AiService>((ref) => const DisabledAiService());
