import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/di/bootstrap.dart';
import 'core/utils/logger.dart';

/// Application entry point.
///
/// Boots the offline‑first persistence layer (encrypted‑at‑rest Isar + secure
/// storage) and wires the Isar‑backed repositories via DI overrides. If
/// persistence can't be initialised, the app still launches in the offline
/// in‑memory/guest mode (see `buildProductionOverrides`).
///
/// Firebase is initialised lazily and optionally — the app runs fully offline
/// without a Firebase project. Once `firebase_options.dart` exists (see
/// docs/FIREBASE_SETUP.md), uncomment the initialisation and add the Firebase
/// auth/sync overrides alongside the persistence ones.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();

  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  final overrides = await buildProductionOverrides();

  runApp(
    ProviderScope(
      overrides: overrides,
      child: const LumenApp(),
    ),
  );
}
