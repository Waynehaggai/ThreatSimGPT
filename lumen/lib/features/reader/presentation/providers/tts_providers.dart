import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../data/services/flutter_tts_service.dart';
import '../../../../domain/entities/reading_progress.dart';
import '../../../../domain/services/tts_service.dart';
import 'reader_providers.dart';
import 'tts_controller.dart';

/// The active [TtsService]. Native `flutter_tts` by default; a fake is injected
/// in tests via override.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = FlutterTtsService();
  ref.onDispose(service.dispose); // closes its stream controllers
  return service;
});

/// Per-book read-aloud controller. Persists the spoken sentence to reading
/// progress so playback resumes from the exact sentence next time.
final ttsControllerProvider = Provider.family<TtsPlaybackController, String>((
  ref,
  bookId,
) {
  final controller = TtsPlaybackController(
    ref.watch(ttsServiceProvider),
    onSentence: (sentence) {
      // Reflect audio position into reading progress (fire-and-forget).
      final repo = ref.read(progressRepositoryProvider);
      final deviceId = ref.read(deviceIdProvider);
      repo.saveProgress(
        ReadingProgress(
          bookId: bookId,
          updatedAt: DateTime.now(),
          deviceId: deviceId,
          ttsSentenceIndex: sentence.index,
          charOffset: sentence.start,
          chapterId: sentence.chapterId,
        ),
      );
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
});
