import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/theme/reading_theme.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/reading_settings.dart';
import 'package:lumen/features/reader/presentation/providers/sample_content.dart';
import 'package:lumen/features/reader/presentation/rendering/reader_typography.dart';
import 'package:lumen/features/reader/presentation/widgets/smart_reader_view.dart';

void main() {
  testWidgets('renders reflowed content and reports a position', (tester) async {
    var reported = false;
    final content = sampleBookContent('b1', 'Demo Book');
    final typo = ReaderTypography(
      const ReadingSettings(),
      ReadingPalette.of(ReadingTheme.light),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartReaderView(
            content: content,
            typography: typo,
            navigation: PageNavigation.verticalScroll,
            initialPercent: 0,
            onPosition: ({required percent, required charOffset, chapterId}) {
              reported = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Reflowed body text is present.
    expect(find.textContaining('Smart Reading Mode'), findsOneWidget);

    // Scrolling drives a position report.
    await tester.drag(find.byType(SmartReaderView), const Offset(0, -300));
    await tester.pump();
    expect(reported, isTrue);
  });
}
