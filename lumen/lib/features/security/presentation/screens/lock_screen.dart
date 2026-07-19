import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/services/security_service.dart';
import '../providers/app_lock_providers.dart';

/// Full-screen lock shown over the app until the user authenticates.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({required this.method, super.key});

  final AppLockMethod method;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.method == AppLockMethod.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _biometric() async {
    final ok = await ref.read(appLockControllerProvider).unlockBiometric();
    if (!ok && mounted) setState(() => _error = 'Authentication failed');
  }

  void _submitPin() {
    final ok = ref.read(appLockControllerProvider).unlockPin(_pinController.text);
    if (!ok) {
      setState(() => _error = 'Incorrect PIN');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 56, color: AppColors.seed),
              const SizedBox(height: 16),
              Text('${AppConstants.appName} is locked',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              if (widget.method == AppLockMethod.biometric) ...[
                FilledButton.icon(
                  onPressed: _biometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
              ] else ...[
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Enter PIN',
                    counterText: '',
                  ),
                  maxLength: 8,
                  onSubmitted: (_) => _submitPin(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _submitPin, child: const Text('Unlock')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
