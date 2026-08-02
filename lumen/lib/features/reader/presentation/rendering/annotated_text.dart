import 'package:flutter/material.dart';

import '../../../../domain/entities/annotation.dart';
import '../../../../domain/entities/enums.dart';

/// Builds an [InlineSpan] for a block of text with any overlapping highlights
/// and underlines painted in.
///
/// [baseOffset] is the block's absolute character offset in the book's text
/// stream; annotation offsets are absolute too, so they are translated into the
/// block's local coordinates here. Pure and deterministic — unit-tested without
/// pumping widgets (see `test/reader/annotated_text_test.dart`).
InlineSpan buildAnnotatedSpan({
  required String text,
  required int baseOffset,
  required TextStyle style,
  required List<Annotation> annotations,
}) {
  final len = text.length;
  if (len == 0 || annotations.isEmpty) {
    return TextSpan(text: text, style: style);
  }

  // Local-coordinate ranges that actually overlap this block.
  final ranges = <Annotation>[];
  final cuts = <int>{0, len};
  for (final a in annotations) {
    final s = a.startOffset;
    final e = a.endOffset;
    if (s == null || e == null) continue;
    final ls = (s - baseOffset).clamp(0, len);
    final le = (e - baseOffset).clamp(0, len);
    if (le > ls) {
      ranges.add(a);
      cuts
        ..add(ls)
        ..add(le);
    }
  }
  if (ranges.isEmpty) return TextSpan(text: text, style: style);

  final points = cuts.toList()..sort();
  final children = <InlineSpan>[];
  for (var i = 0; i < points.length - 1; i++) {
    final start = points[i];
    final end = points[i + 1];
    if (end <= start) continue;

    var segStyle = style;
    for (final a in ranges) {
      final ls = (a.startOffset! - baseOffset).clamp(0, len);
      final le = (a.endOffset! - baseOffset).clamp(0, len);
      if (ls <= start && le >= end) {
        segStyle = _applyAnnotation(segStyle, a);
      }
    }
    children.add(TextSpan(text: text.substring(start, end), style: segStyle));
  }
  return TextSpan(style: style, children: children);
}

TextStyle _applyAnnotation(TextStyle style, Annotation a) {
  final color = a.colorValue != null ? Color(a.colorValue!) : null;
  return switch (a.type) {
    AnnotationType.highlight => style.copyWith(
        backgroundColor: (color ?? const Color(0xFFFFF176)).withValues(
          alpha: 0.45,
        ),
      ),
    AnnotationType.underline => style.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: color,
        decorationThickness: 2,
      ),
    // Notes / sticky notes don't restyle the text; they surface as markers.
    AnnotationType.note || AnnotationType.stickyNote => style,
  };
}
