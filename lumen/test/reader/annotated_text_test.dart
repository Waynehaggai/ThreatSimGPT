import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/annotation.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/features/reader/presentation/rendering/annotated_text.dart';

void main() {
  const style = TextStyle(fontSize: 16);
  final now = DateTime(2026);

  Annotation highlight(int start, int end, {int? color}) => Annotation(
        id: 'a',
        bookId: 'b',
        type: AnnotationType.highlight,
        createdAt: now,
        updatedAt: now,
        colorValue: color,
        startOffset: start,
        endOffset: end,
      );

  test('no annotations yields a plain span', () {
    final span = buildAnnotatedSpan(
      text: 'Hello world',
      baseOffset: 0,
      style: style,
      annotations: const [],
    ) as TextSpan;
    expect(span.text, 'Hello world');
    expect(span.children, isNull);
  });

  test('a highlight splits the text and colours the covered segment', () {
    final span = buildAnnotatedSpan(
      text: 'Hello world',
      baseOffset: 0,
      style: style,
      annotations: [highlight(2, 5)],
    ) as TextSpan;

    final children = span.children!.cast<TextSpan>();
    expect(children.length, 3); // [0,2) [2,5) [5,11)
    expect(children[0].style?.backgroundColor, isNull);
    expect(children[1].style?.backgroundColor, isNotNull);
    expect(children[2].style?.backgroundColor, isNull);
    // The coloured segment is the selected substring.
    expect(children[1].text, 'llo');
  });

  test('offsets are translated by the block base offset', () {
    // Block starts at char 100; highlight covers absolute 102–105.
    final span = buildAnnotatedSpan(
      text: 'Hello world',
      baseOffset: 100,
      style: style,
      annotations: [highlight(102, 105)],
    ) as TextSpan;
    final children = span.children!.cast<TextSpan>();
    expect(children[1].text, 'llo');
    expect(children[1].style?.backgroundColor, isNotNull);
  });

  test('annotations outside the block are ignored', () {
    final span = buildAnnotatedSpan(
      text: 'Hello world',
      baseOffset: 0,
      style: style,
      annotations: [highlight(50, 60)],
    ) as TextSpan;
    expect(span.children, isNull);
    expect(span.text, 'Hello world');
  });
}
