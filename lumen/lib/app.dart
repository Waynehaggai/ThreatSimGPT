import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/security/presentation/providers/app_lock_controller.dart';
import 'features/security/presentation/providers/app_lock_providers.dart';
import 'features/security/presentation/screens/lock_screen.dart';

/// Root widget. Wires the Material 3 themes and the GoRouter into a
/// [MaterialApp.router], with an app-lock gate overlaid on every page.
class LumenApp extends ConsumerWidget {
  const LumenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => _LockGate(child: child ?? const SizedBox()),
    );
  }
}

/// Observes app lifecycle for auto-lock and overlays the [LockScreen] when the
/// app is locked.
class _LockGate extends ConsumerStatefulWidget {
  const _LockGate({required this.child});
  final Widget child;

  @override
  ConsumerState<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<_LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLockControllerProvider).onLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appLockControllerProvider);
    return ValueListenableBuilder<AppLockState>(
      valueListenable: controller.state,
      builder: (context, lock, _) {
        if (lock.enabled && lock.locked) {
          return LockScreen(method: lock.method);
        }
        return widget.child;
      },
    );
  }
}
