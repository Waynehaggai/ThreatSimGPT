// Integration smoke test — run on a device/emulator with:
//   flutter test integration_test
//
// Boots the app end-to-end (real DI bootstrap, in-memory/guest fallback when
// Firebase isn't configured) and drives the offline guest flow into the library.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumen/app.dart';
import 'package:lumen/core/di/bootstrap.dart';
import 'package:lumen/core/utils/logger.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots to sign-in and enters the library as a guest', (
    tester,
  ) async {
    AppLogger.init();
    final overrides = await buildProductionOverrides();

    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const LumenApp()),
    );
    await tester.pumpAndSettle();

    // Sign-in offers a guest path.
    expect(find.text('Continue as guest'), findsOneWidget);

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    // Lands in the (empty) library.
    expect(find.text('Import your first book'), findsOneWidget);
  });
}
