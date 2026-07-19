import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/daos/sync_queue_dao.dart';
import '../../data/local/isar_database.dart';
import '../../data/repositories/isar_annotation_repository.dart';
import '../../data/repositories/isar_library_repository.dart';
import '../../data/repositories/isar_progress_repository.dart';
import '../../data/repositories/isar_settings_repository.dart';
import '../../data/services/secure_security_service.dart';
import '../../features/library/presentation/providers/library_providers.dart';
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

    log.info('Isar database opened; production repositories wired.');

    return [
      securityServiceProvider.overrideWithValue(security),
      libraryRepositoryProvider
          .overrideWithValue(IsarLibraryRepository(db.isar, syncQueue)),
      annotationRepositoryProvider
          .overrideWithValue(IsarAnnotationRepository(db.isar, syncQueue)),
      progressRepositoryProvider
          .overrideWithValue(IsarProgressRepository(db.isar, syncQueue)),
      settingsRepositoryProvider
          .overrideWithValue(IsarSettingsRepository(db.isar, syncQueue)),
    ];
  } on Object catch (e, s) {
    log.warning('Persistence bootstrap failed; falling back to in-memory.', e);
    log.debug('$s');
    return const [];
  }
}
