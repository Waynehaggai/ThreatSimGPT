import 'package:flutter/material.dart';

import '../../../../core/theme/reading_theme.dart';
import '../../../../domain/services/tts_service.dart';
import '../providers/tts_controller.dart';

/// Read-aloud transport shown above the bottom bar while TTS is active:
/// play/pause, stop, speed, and a sleep timer.
class TtsBar extends StatelessWidget {
  const TtsBar({
    required this.state,
    required this.palette,
    required this.onPlayPause,
    required this.onStop,
    required this.onSpeed,
    required this.onSleepTimer,
    super.key,
  });

  final TtsUiState state;
  final ReadingPalette palette;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSpeed;
  final ValueChanged<Duration?> onSleepTimer;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              iconSize: 32,
              icon: Icon(state.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded),
              onPressed: onPlayPause,
            ),
            IconButton(
              icon: const Icon(Icons.stop_rounded),
              onPressed: onStop,
            ),
            const Spacer(),
            // Playback speed cycler.
            TextButton(
              onPressed: () {
                final next =
                    _speeds[(_speeds.indexOf(state.speed) + 1) % _speeds.length];
                onSpeed(next);
              },
              child: Text('${state.speed}x'),
            ),
            PopupMenuButton<Duration?>(
              tooltip: 'Sleep timer',
              icon: const Icon(Icons.bedtime_outlined),
              onSelected: onSleepTimer,
              itemBuilder: (_) => const [
                PopupMenuItem(value: Duration(minutes: 5), child: Text('5 min')),
                PopupMenuItem(value: Duration(minutes: 15), child: Text('15 min')),
                PopupMenuItem(value: Duration(minutes: 30), child: Text('30 min')),
                PopupMenuItem(value: null, child: Text('Off')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the transport should be visible for [state].
bool ttsBarVisible(TtsUiState state) => state.status != TtsState.stopped;
