import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/theme/reading_theme.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/reading_settings.dart';
import 'package:lumen/features/reader/presentation/rendering/reader_typography.dart';
import 'package:lumen/features/reader/presentation/widgets/smart_reader_view.dart';

BookContent _content() {
  var offset = 0;
  final blocks = <ContentBlock>[];
  for (var i = 0; i < 60; i++) {
    final text = 'Paragraph $i. ${'word ' * 16}'.trim();
    blocks.add(
      ContentBlock(type: BlockType.paragraph, text: text, charOffset: offset),
    );
    offset += text.length;
  }
  return BookContent(
    bookId: 'b',
    chapters: [Chapter(id: 'c1', title: 'One', order: 0, blocks: blocks)],
  );
}

void main() {
  final typography = ReaderTypography(
    const ReadingSettings(fontFamily: '', fontSizeSp: 18),
    ReadingPalette.of(ReadingTheme.light),
  );

  Future<void> pumpReader(
    WidgetTester tester, {
    required void Function(double) onPercent,
    required VoidCallback onToggleChrome,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartReaderView(
            content: _content(),
            typography: typography,
            navigation: PageNavigation.pageTurn,
            initialPercent: 0,
            onToggleChrome: onToggleChrome,
            onPosition: ({required percent, required charOffset, chapterId}) =>
                onPercent(percent),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the right side turns to the next page', (tester) async {
    var percent = 0.0;
    await pumpReader(tester,
        onPercent: (p) => percent = p, onToggleChrome: () {});

    final size = tester.getSize(find.byType(SmartReaderView));
    await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5));
    await tester.pumpAndSettle();

    expect(percent, greaterThan(0), reason: 'advanced past the first page');
  });

  testWidgets('tapping the left side turns back', (tester) async {
    var percent = 0.0;
    await pumpReader(tester,
        onPercent: (p) => percent = p, onToggleChrome: () {});
    final size = tester.getSize(find.byType(SmartReaderView));

    await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5)); // next
    await tester.pumpAndSettle();
    final advanced = percent;
    expect(advanced, greaterThan(0));

    await tester.tapAt(Offset(size.width * 0.1, size.height * 0.5)); // previous
    await tester.pumpAndSettle();
    expect(percent, lessThan(advanced), reason: 'returned toward the start');
  });

  testWidgets('a centre tap toggles the chrome instead of turning', (
    tester,
  ) async {
    var toggles = 0;
    var percent = -1.0;
    await pumpReader(
      tester,
      onPercent: (p) => percent = p,
      onToggleChrome: () => toggles++,
    );

    final size = tester.getSize(find.byType(SmartReaderView));
    await tester.tapAt(Offset(size.width * 0.5, size.height * 0.45));
    await tester.pumpAndSettle();

    expect(toggles, 1);
    expect(percent, -1.0, reason: 'centre tap must not turn the page');
  });
}
