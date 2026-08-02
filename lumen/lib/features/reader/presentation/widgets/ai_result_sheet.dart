import 'package:flutter/material.dart';

import '../../../../core/result/result.dart';

/// Bottom sheet that shows an AI result — a loading state while the request is
/// in flight, then the text (or a friendly error). Used by the reader's
/// "Explain", "Define", and "Summarize" AI actions.
class AiResultSheet extends StatelessWidget {
  const AiResultSheet({required this.title, required this.future, super.key});

  final String title;
  final Future<Result<String>> future;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Future<Result<String>> future,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AiResultSheet(title: title, future: future),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Result<String>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final result = snapshot.data!;
              return result.fold(
                onSuccess: (text) => SelectableText(
                  text.isEmpty ? 'No response.' : text,
                  style: theme.textTheme.bodyLarge,
                ),
                onFailure: (f) => Text(
                  f.message,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
