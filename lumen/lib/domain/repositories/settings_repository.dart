import '../../core/result/result.dart';
import '../entities/reading_settings.dart';

/// Contract for reader/app settings persistence.
abstract interface class SettingsRepository {
  Stream<ReadingSettings> watchSettings();
  Future<ReadingSettings> getSettings();
  Future<Result<void>> saveSettings(ReadingSettings settings);
}
