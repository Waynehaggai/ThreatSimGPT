import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/library/presentation/widgets/library_empty_state.dart';

void main() {
  testWidgets('empty state shows a prompt and fires the import callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryEmptyState(onImport: () => tapped = true)),
      ),
    );

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Import your first book'), findsOneWidget);

    await tester.tap(find.text('Import your first book'));
    expect(tapped, isTrue);
  });
}
