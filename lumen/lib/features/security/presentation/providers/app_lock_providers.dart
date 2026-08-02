import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import 'app_lock_controller.dart';

/// App-lock controller, seeded from the configured lock method.
final appLockControllerProvider = Provider<AppLockController>((ref) {
  final controller = AppLockController(ref.watch(securityServiceProvider))
    ..start();
  ref.onDispose(controller.dispose);
  return controller;
});
