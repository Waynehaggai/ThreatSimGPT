import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/services/tts_service.dart';

/// Native text-to-speech via `flutter_tts` ([TtsService]).
///
/// Speaks sentence-by-sentence so the UI can highlight the current sentence and
/// resume from the exact one. Background playback and lock-screen/Bluetooth
/// controls are layered on by the `audio_service` handler (see
/// `LumenAudioHandler`). Native plugin — verified on device.
class FlutterTtsService implements TtsService {
  FlutterTtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(_onSentenceComplete);
    _tts.setCancelHandler(() => _setState(TtsState.stopped));
  }

  final FlutterTts _tts;

  final _stateCtrl = StreamController<TtsState>.broadcast();
  final _progressCtrl = StreamController<TtsProgress>.broadcast();

  List<String> _sentences = const [];
  int _index = 0;
  TtsState _state = TtsState.stopped;
  Timer? _sleepTimer;

  @override
  Stream<TtsState> get stateStream => _stateCtrl.stream;

  @override
  Stream<TtsProgress> get progressStream => _progressCtrl.stream;

  void _setState(TtsState state) {
    _state = state;
    if (!_stateCtrl.isClosed) _stateCtrl.add(state);
  }

  @override
  Future<Result<List<TtsVoice>>> availableVoices() async {
    try {
      final raw = await _tts.getVoices as List<dynamic>?;
      final voices = (raw ?? [])
          .whereType<Map<Object?, Object?>>()
          .map((v) => TtsVoice(
                id: '${v['name']}',
                name: '${v['name']}',
                locale: '${v['locale']}',
              ))
          .toList();
      return Result.success(voices);
    } on Object catch (e) {
      return Result.failure(UnexpectedFailure('Could not list voices.', cause: e));
    }
  }

  @override
  Future<Result<void>> speak(List<String> sentences, {int startIndex = 0}) async {
    if (sentences.isEmpty) return const Result.success(null);
    _sentences = sentences;
    _index = startIndex.clamp(0, sentences.length - 1);
    await _speakCurrent();
    return const Result.success(null);
  }

  Future<void> _speakCurrent() async {
    if (_index < 0 || _index >= _sentences.length) {
      _setState(TtsState.stopped);
      return;
    }
    _setState(TtsState.playing);
    final text = _sentences[_index];
    _progressCtrl.add(TtsProgress(
      sentenceIndex: _index,
      charStart: 0,
      charEnd: text.length,
    ));
    await _tts.speak(text);
  }

  Future<void> _onSentenceComplete() async {
    if (_state != TtsState.playing) return; // paused/stopped mid-utterance
    _index++;
    if (_index >= _sentences.length) {
      _setState(TtsState.stopped);
      return;
    }
    await _speakCurrent();
  }

  @override
  Future<void> pause() async {
    // flutter_tts pause/continue is unreliable across platforms; stop and
    // remember the index so resume re-speaks the current sentence cleanly.
    _setState(TtsState.paused);
    await _tts.stop();
  }

  @override
  Future<void> resume() async {
    if (_state == TtsState.paused) await _speakCurrent();
  }

  @override
  Future<void> stop() async {
    _setState(TtsState.stopped);
    _sleepTimer?.cancel();
    await _tts.stop();
  }

  @override
  Future<void> setSpeed(double speed) => _tts.setSpeechRate(speed);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> setVoice(String voiceId) async {
    final raw = await _tts.getVoices as List<dynamic>?;
    final match = (raw ?? []).whereType<Map<Object?, Object?>>().firstWhere(
          (v) => '${v['name']}' == voiceId,
          orElse: () => const {},
        );
    if (match.isNotEmpty) {
      await _tts.setVoice({
        'name': '${match['name']}',
        'locale': '${match['locale']}',
      });
    }
  }

  @override
  Future<void> setSleepTimer(Duration? duration) async {
    _sleepTimer?.cancel();
    if (duration == null) return;
    _sleepTimer = Timer(duration, stop);
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    await _tts.stop();
    await _stateCtrl.close();
    await _progressCtrl.close();
  }
}
