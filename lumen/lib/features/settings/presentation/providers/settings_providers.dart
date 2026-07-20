import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/reading_settings.dart';

/// Holds the current [ReadingSettings]. In production this is hydrated from and
/// persisted to the local DB via `SettingsRepository`; here it is an in-memory
/// notifier so the reader and settings UI are fully interactive.
class SettingsNotifier extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() => const ReadingSettings();

  void update(ReadingSettings Function(ReadingSettings) transform) {
    state = transform(state).copyWith(updatedAt: DateTime.now());
    // TODO(persistence): settingsRepository.saveSettings(state) + enqueue sync.
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, ReadingSettings>(
  SettingsNotifier.new,
);
