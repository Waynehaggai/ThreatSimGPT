import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/result/result.dart';
import 'package:lumen/domain/services/tts_service.dart';
import 'package:lumen/features/reader/presentation/providers/tts_controller.dart';
import 'package:lumen/features/reader/presentation/rendering/sentence_segmenter.dart';

/// Controllable fake TTS engine.
class FakeTts implements TtsService {
  final _state = StreamController<TtsState>.broadcast();
  final _progress = StreamController<TtsProgress>.broadcast();
  final List<String> spokenBatches = [];
  int? lastStartIndex;
  double? lastSpeed;

  void emitState(TtsState s) => _state.add(s);
  void emitSentence(int index) => _progress.add(
        TtsProgress(sentenceIndex: index, charStart: 0, charEnd: 1),
      );

  @override
  Stream<TtsState> get stateStream => _state.stream;
  @override
  Stream<TtsProgress> get progressStream => _progress.stream;

  @override
  Future<Result<void>> speak(
    List<String> sentences, {
    int startIndex = 0,
  }) async {
    spokenBatches.add(sentences.join('|'));
    lastStartIndex = startIndex;
    return const Result.success(null);
  }

  @override
  Future<void> setSpeed(double speed) async => lastSpeed = speed;

  @override
  Future<Result<List<TtsVoice>>> availableVoices() async =>
      const Result.success([]);
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setPitch(double pitch) async {}
  @override
  Future<void> setVoice(String voiceId) async {}
  @override
  Future<void> setSleepTimer(Duration? duration) async {}
}

void main() {
  final sentences = [
    const Sentence(index: 0, text: 'First.', start: 0, end: 6),
    const Sentence(index: 1, text: 'Second.', start: 7, end: 14),
    const Sentence(index: 2, text: 'Third.', start: 15, end: 21),
  ];

  test('play forwards sentence texts and start index to the engine', () async {
    final tts = FakeTts();
    final controller = TtsPlaybackController(tts);
    await controller.play(sentences, fromIndex: 1);

    expect(tts.spokenBatches.single, 'First.|Second.|Third.');
    expect(tts.lastStartIndex, 1);
    await controller.dispose();
  });

  test(
    'progress events advance the current sentence + notify onSentence',
    () async {
      Sentence? notified;
      final tts = FakeTts();
      final controller = TtsPlaybackController(
        tts,
        onSentence: (s) => notified = s,
      );
      await controller.play(sentences);

      tts.emitSentence(2);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value.currentIndex, 2);
      expect(controller.currentSentence?.text, 'Third.');
      expect(notified?.index, 2);
      await controller.dispose();
    },
  );

  test('state events flow into the UI state', () async {
    final tts = FakeTts();
    final controller = TtsPlaybackController(tts);
    await controller.play(sentences);

    tts.emitState(TtsState.playing);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.value.isPlaying, isTrue);

    tts.emitState(TtsState.stopped);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.value.isActive, isFalse);
    await controller.dispose();
  });

  test('setSpeed updates state and the engine', () async {
    final tts = FakeTts();
    final controller = TtsPlaybackController(tts);
    await controller.setSpeed(1.5);
    expect(controller.state.value.speed, 1.5);
    expect(tts.lastSpeed, 1.5);
    await controller.dispose();
  });
}
