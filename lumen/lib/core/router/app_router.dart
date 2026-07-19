import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/library/presentation/screens/home_shell.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/search_screen.dart';
import '../../features/reader/presentation/screens/ocr_review_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import 'routes.dart';

/// Bridges a Riverpod stream to a [Listenable] so GoRouter re-evaluates
/// redirects whenever auth state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

/// The app's [GoRouter], reacting to authentication state for redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  return GoRouter(
    initialLocation: Routes.library,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final signedIn = auth.valueOrNull != null; // guest counts as signed in
      final loggingIn = state.matchedLocation == Routes.signIn ||
          state.matchedLocation == Routes.register;

      // Unauthenticated users are sent to sign-in (guest mode is offered there).
      if (!signedIn && !loggingIn) return Routes.signIn;
      if (signedIn && loggingIn) return Routes.library;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        name: Routes.nSignIn,
        builder: (_, __) => const SignInScreen(),
      ),
      // Bottom-nav shell hosting library / stats / settings.
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: Routes.library,
            name: Routes.nLibrary,
            builder: (_, __) => const LibraryScreen(),
          ),
          GoRoute(
            path: Routes.statistics,
            name: Routes.nStatistics,
            builder: (_, __) => const StatisticsScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            name: Routes.nSettings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.reader,
        name: Routes.nReader,
        builder: (_, state) =>
            ReaderScreen(bookId: state.pathParameters['bookId']!),
      ),
      GoRoute(
        path: Routes.search,
        name: Routes.nSearch,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: Routes.ocr,
        name: Routes.nOcr,
        builder: (_, state) =>
            OcrReviewScreen(bookId: state.pathParameters['bookId']!),
      ),
    ],
  );
});
