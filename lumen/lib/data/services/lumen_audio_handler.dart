import 'package:audio_service/audio_service.dart';

import '../../domain/services/tts_service.dart';

/// Bridges Lumen's [TtsService] to the OS media session via `audio_service`,
/// giving read-aloud **background playback and lock-screen / Bluetooth
/// controls**.
///
/// Register once at startup with [initLumenAudioHandler] (requires the platform
/// setup in docs: Android foreground-service entry + iOS background audio mode).
/// Native — verified on device. The reader can run TTS foreground-only without
/// this; the handler simply adds system controls.
class LumenAudioHandler extends BaseAudioHandler with SeekHandler {
  LumenAudioHandler(this._tts) {
    _tts.stateStream.listen(_onTtsState);
    _tts.progressStream.listen((p) {
      // Advance the media session position by sentence index (coarse).
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: Duration(seconds: p.sentenceIndex),
        ),
      );
    });
  }

  final TtsService _tts;

  void _onTtsState(TtsState state) {
    final playing = state == TtsState.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek},
        processingState: state == TtsState.stopped
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        playing: playing,
      ),
    );
  }

  /// Sets the media notification's title/author for the book being read aloud.
  void setBook({
    required String title,
    required String author,
    String? artUri,
  }) {
    mediaItem.add(
      MediaItem(
        id: title,
        title: title,
        artist: author,
        artUri: artUri == null ? null : Uri.tryParse(artUri),
      ),
    );
  }

  @override
  Future<void> play() => _tts.resume();

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> stop() async {
    await _tts.stop();
    await super.stop();
  }
}

/// Initialises the audio session + media notification. Call before `runApp`
/// when background TTS controls are desired.
Future<LumenAudioHandler> initLumenAudioHandler(TtsService tts) {
  return AudioService.init(
    builder: () => LumenAudioHandler(tts),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.lumen.reader.audio',
      androidNotificationChannelName: 'Lumen read-aloud',
      androidNotificationOngoing: true,
    ),
  );
}
