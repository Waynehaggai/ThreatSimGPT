import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/services/security_service.dart';

/// Whether the app should auto-lock on resume: a lock method is set and the app
/// was backgrounded for longer than the grace period. Pure so the timing rule is
/// unit-testable.
bool shouldAutoLock({
  required AppLockMethod method,
  required DateTime? backgroundedAt,
  required DateTime now,
  Duration grace = AppConstants.autoLockGracePeriod,
}) {
  if (method == AppLockMethod.none || backgroundedAt == null) return false;
  return now.difference(backgroundedAt) >= grace;
}

class AppLockState {
  const AppLockState({this.locked = false, this.method = AppLockMethod.none});
  final bool locked;
  final AppLockMethod method;

  bool get enabled => method != AppLockMethod.none;

  AppLockState copyWith({bool? locked, AppLockMethod? method}) =>
      AppLockState(locked: locked ?? this.locked, method: method ?? this.method);
}

/// Manages app-lock state: locks on launch (if configured) and auto-locks after
/// inactivity. Framework-light ([ValueListenable]) and driven by an injected
/// [SecurityService] + clock, so its logic is unit-testable.
class AppLockController {
  AppLockController(this._security, {DateTime Function() now = DateTime.now})
      : _now = now;

  final SecurityService _security;
  final DateTime Function() _now;

  final ValueNotifier<AppLockState> state = ValueNotifier(const AppLockState());
  DateTime? _backgroundedAt;

  /// Reads the configured method and locks immediately if one is set.
  void start() {
    final method = _security.lockMethod;
    state.value = AppLockState(locked: method != AppLockMethod.none, method: method);
  }

  /// Feed app lifecycle changes here (from a `WidgetsBindingObserver`).
  void onLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= _now();
      case AppLifecycleState.resumed:
        if (shouldAutoLock(
          method: state.value.method,
          backgroundedAt: _backgroundedAt,
          now: _now(),
        )) {
          state.value = state.value.copyWith(locked: true);
        }
        _backgroundedAt = null;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Attempts biometric / device-credential unlock.
  Future<bool> unlockBiometric() async {
    final result = await _security.authenticate();
    final ok = result.valueOrNull ?? false;
    if (ok) state.value = state.value.copyWith(locked: false);
    return ok;
  }

  /// Attempts PIN unlock.
  bool unlockPin(String pin) {
    final ok = _security.verifyPin(pin);
    if (ok) state.value = state.value.copyWith(locked: false);
    return ok;
  }

  Future<void> setMethod(AppLockMethod method, {String? pin}) async {
    await _security.setLockMethod(method, pin: pin);
    state.value = state.value.copyWith(method: method);
  }

  void dispose() => state.dispose();
}
