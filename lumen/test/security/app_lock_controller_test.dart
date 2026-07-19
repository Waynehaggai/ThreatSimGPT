import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/constants/app_constants.dart';
import 'package:lumen/core/result/result.dart';
import 'package:lumen/domain/services/security_service.dart';
import 'package:lumen/features/security/presentation/providers/app_lock_controller.dart';

class FakeSecurity implements SecurityService {
  FakeSecurity({this.method = AppLockMethod.none, this.authOk = true, this.pin});
  @override
  AppLockMethod method;
  bool authOk;
  String? pin;

  @override
  AppLockMethod get lockMethod => method;

  @override
  Future<Result<bool>> authenticate({String reason = 'Unlock Lumen'}) async =>
      Result.success(authOk);

  @override
  bool verifyPin(String input) => pin != null && input == pin;

  @override
  Future<Result<void>> setLockMethod(AppLockMethod m, {String? pin}) async {
    method = m;
    this.pin = pin;
    return const Result.success(null);
  }

  @override
  Future<bool> isBiometricAvailable() async => true;
  @override
  Future<Result<List<int>>> databaseEncryptionKey() async =>
      const Result.success([]);
}

void main() {
  group('shouldAutoLock', () {
    test('false when no lock method is set', () {
      expect(
        shouldAutoLock(
          method: AppLockMethod.none,
          backgroundedAt: DateTime(2026),
          now: DateTime(2026).add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test('false when never backgrounded', () {
      expect(
        shouldAutoLock(
          method: AppLockMethod.pin,
          backgroundedAt: null,
          now: DateTime(2026),
        ),
        isFalse,
      );
    });

    test('locks only after the grace period elapses', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(
        shouldAutoLock(
          method: AppLockMethod.pin,
          backgroundedAt: t0,
          now: t0.add(const Duration(seconds: 30)),
        ),
        isFalse,
      );
      expect(
        shouldAutoLock(
          method: AppLockMethod.pin,
          backgroundedAt: t0,
          now: t0.add(AppConstants.autoLockGracePeriod + const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });
  });

  group('AppLockController', () {
    test('locks on start when a method is configured', () {
      final c = AppLockController(FakeSecurity(method: AppLockMethod.biometric))
        ..start();
      expect(c.state.value.locked, isTrue);
      expect(c.state.value.enabled, isTrue);
    });

    test('stays unlocked when no method is set', () {
      final c = AppLockController(FakeSecurity())..start();
      expect(c.state.value.locked, isFalse);
    });

    test('auto-locks on resume after the grace period', () async {
      var now = DateTime(2026, 1, 1, 12);
      final c = AppLockController(
        FakeSecurity(method: AppLockMethod.biometric, authOk: true),
        now: () => now,
      )..start();
      await c.unlockBiometric();
      expect(c.state.value.locked, isFalse);

      c.onLifecycle(AppLifecycleState.paused);
      now = now.add(AppConstants.autoLockGracePeriod + const Duration(minutes: 1));
      c.onLifecycle(AppLifecycleState.resumed);
      expect(c.state.value.locked, isTrue);
    });

    test('does not lock on a brief background', () async {
      var now = DateTime(2026, 1, 1, 12);
      final c = AppLockController(
        FakeSecurity(method: AppLockMethod.pin, pin: '1234'),
        now: () => now,
      )..start();
      c.unlockPin('1234');
      expect(c.state.value.locked, isFalse);

      c.onLifecycle(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 10));
      c.onLifecycle(AppLifecycleState.resumed);
      expect(c.state.value.locked, isFalse);
    });

    test('unlockPin succeeds only with the correct PIN', () {
      final c = AppLockController(
        FakeSecurity(method: AppLockMethod.pin, pin: '4321'),
      )..start();
      expect(c.unlockPin('0000'), isFalse);
      expect(c.state.value.locked, isTrue);
      expect(c.unlockPin('4321'), isTrue);
      expect(c.state.value.locked, isFalse);
    });
  });
}
