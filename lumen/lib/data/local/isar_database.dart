import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/annotation_models.dart';
import 'models/library_models.dart';
import 'models/reading_models.dart';
import 'models/sync_models.dart';

/// Owns the single [Isar] instance and its schema registration.
///
/// ## A note on at-rest encryption
/// Isar 3 (community) does **not** provide built-in database encryption. On
/// mobile, the DB lives in the app's private sandbox, which the OS encrypts as
/// part of device encryption (file-based encryption on Android, Data Protection
/// on iOS). Truly sensitive values — auth tokens, the PIN hash, and any
/// field-level keys — are kept out of Isar and stored in the platform secure
/// enclave via `flutter_secure_storage` (see `SecurityService`).
///
/// For a regulated at-rest requirement, swap the engine for a SQLCipher-backed
/// store behind the same repository interfaces (tracked in ROADMAP M5). The
/// [encryptionKey] hook is threaded through now so that migration is contained
/// to this file.
class IsarDatabase {
  IsarDatabase._(this.isar);

  final Isar isar;

  static IsarDatabase? _instance;

  /// Opens (or returns the already-open) database.
  static Future<IsarDatabase> open({
    // ignore: avoid_unused_constructor_parameters
    List<int>? encryptionKey,
    String? directoryOverride,
  }) async {
    final existing = _instance;
    if (existing != null) return existing;

    final dir = directoryOverride ??
        (await getApplicationDocumentsDirectory()).path;

    final isar = await Isar.open(
      [
        BookModelSchema,
        CollectionModelSchema,
        AnnotationModelSchema,
        BookmarkModelSchema,
        ProgressModelSchema,
        SettingsModelSchema,
        StatsModelSchema,
        SyncOperationModelSchema,
      ],
      directory: dir,
      name: 'lumen',
      inspector: false,
    );

    return _instance = IsarDatabase._(isar);
  }

  Future<void> close() async {
    await isar.close();
    _instance = null;
  }
}
