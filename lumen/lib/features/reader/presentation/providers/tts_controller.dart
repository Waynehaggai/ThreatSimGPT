import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/services/tts_service.dart';
import '../rendering/sentence_segmenter.dart';

/// Immutable read-aloud UI state.
class TtsUiState {
  const TtsUiState({
    this.status = TtsState.stopped,
    this.currentIndex = 0,
    this.speed = 1.0,
  });

  final TtsState status;
  final int currentIndex;
  final double speed;

  bool get isPlaying => status == TtsState.playing;
  bool get isActive => status != TtsState.stopped;

  TtsUiState copyWith({TtsState? status, int? currentIndex, double? speed}) =>
      TtsUiState(
        status: status ?? this.status,
        currentIndex: currentIndex ?? this.currentIndex,
        speed: speed ?? this.speed,
      );
}

/// Drives a [TtsService] over a book's [Sentence] list and exposes the current
/// position for highlighting + resume.
///
/// A plain, framework-light controller (a [ValueListenable] of [TtsUiState]) so
/// its state machine is unit-testable with a fake [TtsService], while the UI
/// binds via `ValueListenableBuilder`.
class TtsPlaybackController {
  TtsPlaybackController(this._service, {this.onSentence});

  final TtsService _service;

  /// Called each time the spoken sentence advances (for progress persistence
  /// and auto-scroll).
  final void Function(Sentence sentence)? onSentence;

  final ValueNotifier<TtsUiState> state = ValueNotifier(const TtsUiState());
  List<Sentence> _sentences = const [];
  StreamSubscription<TtsProgress>? _progressSub;
  StreamSubscription<TtsState>? _stateSub;

  void _ensureSubscribed() {
    _progressSub ??= _service.progressStream.listen((p) {
      state.value = state.value.copyWith(currentIndex: p.sentenceIndex);
      final s = currentSentence;
      if (s != null) onSentence?.call(s);
    });
    _stateSub ??= _service.stateStream.listen((s) {
      state.value = state.value.copyWith(status: s);
    });
  }

  Sentence? get currentSentence {
    final i = state.value.currentIndex;
    return (i >= 0 && i < _sentences.length) ? _sentences[i] : null;
  }

  /// Starts (or restarts) playback over [sentences] from [fromIndex].
  Future<void> play(List<Sentence> sentences, {int fromIndex = 0}) async {
    _ensureSubscribed();
    _sentences = sentences;
    await _service.speak(
      sentences.map((s) => s.text).toList(),
      startIndex: fromIndex,
    );
  }

  Future<void> pause() => _service.pause();
  Future<void> resume() => _service.resume();
  Future<void> stop() => _service.stop();

  Future<void> setSpeed(double speed) {
    state.value = state.value.copyWith(speed: speed);
    return _service.setSpeed(speed);
  }

  Future<void> setSleepTimer(Duration? duration) =>
      _service.setSleepTimer(duration);

  /// Jumps to a sentence (e.g. tapping text while reading aloud).
  Future<void> seekTo(int index) async {
    if (_sentences.isEmpty) return;
    await play(_sentences, fromIndex: index.clamp(0, _sentences.length - 1));
  }

  Future<void> dispose() async {
    await _progressSub?.cancel();
    await _stateSub?.cancel();
    await _service.stop();
    state.dispose();
  }
}
