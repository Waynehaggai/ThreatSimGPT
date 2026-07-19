import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/daos/sync_queue_dao.dart';
import '../../data/local/isar_database.dart';
import '../../data/parsers/docx_parser.dart';
import '../../data/parsers/document_parsing_service_impl.dart';
import '../../data/parsers/epub_parser.dart';
import '../../data/parsers/pdf_parser.dart';
import '../../data/parsers/plain_text_parser.dart';
import '../../data/repositories/isar_annotation_repository.dart';
import '../../data/repositories/isar_library_repository.dart';
import '../../data/repositories/isar_progress_repository.dart';
import '../../data/repositories/isar_settings_repository.dart';
import '../../data/repositories/isar_statistics_repository.dart';
import '../../data/services/file_import_service.dart';
import '../../data/services/secure_security_service.dart';
import '../../data/sync/isar_local_merge_sink.dart';
import '../../data/sync/remote_data_source.dart';
import '../../data/sync/sync_engine.dart';
import '../../features/library/presentation/providers/library_providers.dart';
import '../network/connectivity_service.dart';
import '../utils/logger.dart';
import 'repository_providers.dart';

/// Builds the production DI overrides: opens the encrypted-at-rest Isar DB,
/// wires the Isar-backed repositories, and hydrates the security service.
///
/// Resilient by design — if platform channels or the database are unavailable
/// (e.g. an unsupported environment), it logs and returns an empty override
/// list so the app still boots in the offline in-memory/guest mode rather than
/// crashing. The caller passes the result to `ProviderScope(overrides: …)`.
Future<List<Override>> buildProductionOverrides() async {
  final log = AppLogger('bootstrap');
  try {
    final security = SecureSecurityService();
    await security.init();

    final keyResult = await security.databaseEncryptionKey();
    final db = await IsarDatabase.open(encryptionKey: keyResult.valueOrNull);
    final syncQueue = SyncQueueDao(db.isar);

    final parsing = DocumentParsingServiceImpl(const [
      PlainTextParser(),
      EpubParser(),
      PdfParser(),
      DocxParser(),
    ]);
    final importService = FileImportService(parsing);

    // Sync engine over the durable Isar queue. Uses a no-op remote until a
    // Firebase backend is wired (swap in FirestoreRemoteDataSource + the
    // FirebaseAuthRepository override once firebase_options.dart exists).
    final connectivity = ConnectivityService();
    final syncEngine = SyncEngine(
      queue: syncQueue,
      remote: const NoopRemoteDataSource(),
      isOnline: () => connectivity.isOnline,
      onlineChanges: connectivity.onlineChanges,
      mergeSink: IsarLocalMergeSink(db.isar),
    );

    log.info('Isar database opened; production repositories wired.');

    return [
      securityServiceProvider.overrideWithValue(security),
      documentParsingServiceProvider.overrideWithValue(parsing),
      importServiceProvider.overrideWithValue(importService),
      syncRepositoryProvider.overrideWithValue(syncEngine),
      libraryRepositoryProvider.overrideWithValue(
          IsarLibraryRepository(db.isar, syncQueue, importService)),
      annotationRepositoryProvider
          .overrideWithValue(IsarAnnotationRepository(db.isar, syncQueue)),
      progressRepositoryProvider
          .overrideWithValue(IsarProgressRepository(db.isar, syncQueue)),
      settingsRepositoryProvider
          .overrideWithValue(IsarSettingsRepository(db.isar, syncQueue)),
      statisticsRepositoryProvider
          .overrideWithValue(IsarStatisticsRepository(db.isar, syncQueue)),
    ];
  } on Object catch (e, s) {
    log.warning('Persistence bootstrap failed; falling back to in-memory.', e);
    log.debug('$s');
    return const [];
  }
}
