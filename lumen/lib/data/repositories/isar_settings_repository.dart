import 'package:isar_community/isar.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/reading_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/models/reading_models.dart';
import '../mappers/reading_mappers.dart';

/// Isar-backed [SettingsRepository]. Settings are a singleton row synced as one
/// document so every device reads identically.
class IsarSettingsRepository implements SettingsRepository {
  IsarSettingsRepository(this._isar, this._syncQueue);

  final Isar _isar;
  final SyncQueueDao _syncQueue;

  @override
  Stream<ReadingSettings> watchSettings() {
    return _isar.settingsModels
        .watchObject(SettingsModel.singletonId, fireImmediately: true)
        .map((model) => model?.toEntity() ?? const ReadingSettings());
  }

  @override
  Future<ReadingSettings> getSettings() async {
    final model =
        await _isar.settingsModels.get(SettingsModel.singletonId);
    return model?.toEntity() ?? const ReadingSettings();
  }

  @override
  Future<Result<void>> saveSettings(ReadingSettings settings) async {
    try {
      final stamped = settings.copyWith(updatedAt: DateTime.now());
      await _isar.writeTxn(
          () => _isar.settingsModels.put(stamped.toModel()));
      await _syncQueue.enqueue(
        entityType: SyncEntityType.settings,
        entityId: 'current',
        action: SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to save settings.', cause: e));
    }
  }
}
