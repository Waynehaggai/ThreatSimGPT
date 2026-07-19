import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/user_account.dart';
import '../providers/auth_providers.dart';

/// Entry screen offering Google / Apple / email sign-in and a prominent
/// "Continue as guest" path (offline-first: no account required).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _run(Future<Result<UserAccount>> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    // Router redirect handles navigation on success; show failures inline.
    final failure = result.failureOrNull;
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.auto_stories_rounded,
                  size: 72, color: AppColors.seed),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.tagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(flex: 3),
              _SignInButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onPressed: _busy
                    ? null
                    : () => _run(controller.signInWithGoogle),
              ),
              const SizedBox(height: 12),
              _SignInButton(
                icon: Icons.apple_rounded,
                label: 'Continue with Apple',
                onPressed:
                    _busy ? null : () => _run(controller.signInWithApple),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _run(controller.continueAsGuest),
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Continue as guest'),
              ),
              const SizedBox(height: 16),
              Text(
                'Guest mode works fully offline. Your library, notes and '
                'progress move with you when you create an account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(flex: 2),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
