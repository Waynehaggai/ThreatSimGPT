import '../../core/result/result.dart';

enum TtsState { stopped, playing, paused }

/// An available TTS voice (native, or a future premium AI voice).
class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.name,
    required this.locale,
    this.isPremium = false,
  });

  final String id;
  final String name;
  final String locale;
  final bool isPremium;
}

/// Highlight event emitted as the engine speaks, driving sentence highlighting.
class TtsProgress {
  const TtsProgress({
    required this.sentenceIndex,
    required this.charStart,
    required this.charEnd,
  });

  final int sentenceIndex;
  final int charStart;
  final int charEnd;
}

/// Contract for read-aloud. Backed by native TTS + `audio_service` for
/// background playback and lock-screen/Bluetooth controls. The interface is
/// voice-engine agnostic so premium AI voices can be added later.
abstract interface class TtsService {
  Stream<TtsState> get stateStream;

  /// Sentence-level progress for highlighting and exact resume.
  Stream<TtsProgress> get progressStream;

  Future<Result<List<TtsVoice>>> availableVoices();

  /// Begins speaking [sentences] starting at [startIndex]. Sentences are
  /// pre-segmented so resume/highlight indices stay stable.
  Future<Result<void>> speak(List<String> sentences, {int startIndex = 0});

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  Future<void> setSpeed(double speed);
  Future<void> setPitch(double pitch);
  Future<void> setVoice(String voiceId);

  /// Auto-stops playback after [duration] (sleep timer).
  Future<void> setSleepTimer(Duration? duration);
}
