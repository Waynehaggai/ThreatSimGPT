import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/reading_progress.dart';

/// "Continue from page X?" dialog shown when another device has read further.
///
/// Nothing is auto-overwritten — the user chooses. Returns `true` to jump to the
/// newer (remote) position, `false`/null to stay at the local one.
class ResumePrompt extends StatelessWidget {
  const ResumePrompt({required this.remote, this.localPercent, super.key});

  final ReadingProgress remote;
  final double? localPercent;

  static Future<bool?> show(
    BuildContext context, {
    required ReadingProgress remote,
    double? localPercent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ResumePrompt(remote: remote, localPercent: localPercent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remotePct = (remote.percent * 100).round();
    final when = DateFormat.yMMMd().add_jm().format(remote.updatedAt.toLocal());

    return AlertDialog(
      icon: const Icon(Icons.devices_rounded),
      title: const Text('Continue reading?'),
      content: Text(
        'Another device reached $remotePct% on $when.'
        '${localPercent != null ? '\nThis device is at ${(localPercent! * 100).round()}%.' : ''}'
        '\n\nJump to the furthest position?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay here'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Continue from $remotePct%'),
        ),
      ],
    );
  }
}
