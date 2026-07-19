import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/logger.dart';

/// Application entry point.
///
/// Firebase is initialised lazily and optionally: the app runs fully offline in
/// guest mode without a Firebase project. Once `firebase_options.dart` exists
/// (see docs/FIREBASE_SETUP.md), uncomment the initialisation block and override
/// the auth/sync repository providers with their Firebase implementations.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();

  // ── Optional Firebase bootstrap ───────────────────────────────────────────
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(
    ProviderScope(
      overrides: const [
        // In production, override the default in-memory/guest providers with
        // Isar + Firebase implementations here, e.g.:
        //   libraryRepositoryProvider.overrideWithValue(isarLibraryRepo),
        //   authRepositoryProvider.overrideWithValue(firebaseAuthRepo),
      ],
      child: const LumenApp(),
    ),
  );
}
