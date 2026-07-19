import 'package:isar/isar.dart';

import '../../../domain/entities/enums.dart';

part 'sync_models.g.dart';

/// Isar persistence model for a queued [SyncOperation]. This is the durable
/// backing store the sync engine drains; scheduling logic lives in `SyncQueue`.
@collection
class SyncOperationModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String uid;

  @Enumerated(EnumType.name)
  late SyncEntityType entityType;

  late String entityId;

  @Enumerated(EnumType.name)
  late SyncAction action;

  @Enumerated(EnumType.name)
  @Index()
  late SyncOperationStatus status;

  late int retryCount;
  String? lastError;

  @Index()
  DateTime? nextAttemptAt;

  /// Optional JSON-encoded entity snapshot (Isar has no Map type).
  String? payloadJson;

  @Index()
  late DateTime createdAt;
}
