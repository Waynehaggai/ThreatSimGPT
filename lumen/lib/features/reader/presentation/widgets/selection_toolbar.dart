import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Floating toolbar shown when the user has selected text in Smart Mode.
///
/// Offers highlight colours, an underline, a note, and copy — each acting on the
/// current selection. Kept presentational: the reader wires the callbacks to the
/// [AnnotationController].
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.onHighlight,
    required this.onUnderline,
    required this.onNote,
    required this.onCopy,
    required this.onDismiss,
    this.onExplain,
    super.key,
  });

  final ValueChanged<int> onHighlight; // ARGB colour value
  final VoidCallback onUnderline;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback onDismiss;

  /// AI "Explain" action — shown only when the AI module is enabled.
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final color in AppColors.highlightSwatches)
              _Swatch(
                color: color,
                onTap: () => onHighlight(color.toARGB32()),
              ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Underline',
              icon: const Icon(Icons.format_underlined_rounded),
              onPressed: onUnderline,
            ),
            IconButton(
              tooltip: 'Note',
              icon: const Icon(Icons.sticky_note_2_outlined),
              onPressed: onNote,
            ),
            if (onExplain != null)
              IconButton(
                tooltip: 'Explain (AI)',
                icon: const Icon(Icons.auto_awesome_rounded),
                onPressed: onExplain,
              ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_rounded),
              onPressed: onCopy,
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: Icon(Icons.close_rounded, color: theme.colorScheme.outline),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
