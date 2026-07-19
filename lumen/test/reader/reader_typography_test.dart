import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/theme/reading_theme.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/reading_settings.dart';
import 'package:lumen/features/reader/presentation/rendering/reader_typography.dart';

void main() {
  final palette = ReadingPalette.of(ReadingTheme.light);

  test('maps fontWeight setting to the nearest FontWeight', () {
    final typo = ReaderTypography(
      const ReadingSettings(fontWeight: 700),
      palette,
    );
    expect(typo.paragraph.fontWeight, FontWeight.w700);
  });

  test('headings scale larger than body and shrink by level', () {
    final typo = ReaderTypography(
      const ReadingSettings(fontSizeSp: 18),
      palette,
    );
    expect(typo.heading(0).fontSize, greaterThan(typo.paragraph.fontSize!));
    expect(typo.heading(3).fontSize, lessThan(typo.heading(0).fontSize!));
  });

  test('applies the palette text colour and maps alignment', () {
    final typo = ReaderTypography(
      const ReadingSettings(textAlign: ReadingTextAlign.justify),
      palette,
    );
    expect(typo.paragraph.color, palette.text);
    expect(typo.textAlign, TextAlign.justify);
  });

  test('caption is smaller than body', () {
    final typo = ReaderTypography(const ReadingSettings(fontSizeSp: 20), palette);
    expect(typo.caption.fontSize, lessThan(20));
  });
}
