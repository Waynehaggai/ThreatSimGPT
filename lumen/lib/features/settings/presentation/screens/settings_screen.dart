import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../domain/entities/enums.dart';
import '../../../../domain/repositories/sync_repository.dart';
import '../../../../domain/services/security_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../security/presentation/providers/app_lock_providers.dart';
import '../providers/settings_providers.dart';

/// Top-level settings: account, default reading mode, theme, sync, security.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(user?.displayName ?? 'Guest'),
            subtitle: Text(user?.isGuest ?? true
                ? 'Guest — sign in to sync across devices'
                : (user?.email ?? '')),
            trailing: (user?.isGuest ?? true)
                ? const Icon(Icons.chevron_right_rounded)
                : null,
          ),
          _sectionHeader(context, 'Reading'),
          ListTile(
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            title: const Text('Default reading mode'),
            subtitle: Text(settings.defaultReadingMode == ReadingMode.smart
                ? 'Smart Reading (reflowable)'
                : 'Original (as authored)'),
            trailing: SegmentedButton<ReadingMode>(
              segments: const [
                ButtonSegment(
                    value: ReadingMode.smart, label: Text('Smart')),
                ButtonSegment(
                    value: ReadingMode.original, label: Text('Original')),
              ],
              selected: {settings.defaultReadingMode},
              onSelectionChanged: (s) => ref
                  .read(settingsProvider.notifier)
                  .update((x) => x.copyWith(defaultReadingMode: s.first)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Reader theme'),
            subtitle: Text(settings.theme.name),
            trailing: DropdownButton<ReadingTheme>(
              value: settings.theme,
              underline: const SizedBox.shrink(),
              onChanged: (t) => ref
                  .read(settingsProvider.notifier)
                  .update((x) => x.copyWith(theme: t)),
              items: [
                for (final t in ReadingTheme.values)
                  DropdownMenuItem(value: t, child: Text(t.name)),
              ],
            ),
          ),
          _sectionHeader(context, 'Synchronization'),
          Consumer(
            builder: (context, ref, _) {
              final sync = ref.watch(syncStateProvider).valueOrNull;
              final status = sync?.status ?? SyncStatus.offline;
              final (icon, label) = switch (status) {
                SyncStatus.idle => (
                    Icons.cloud_done_outlined,
                    'Up to date'
                  ),
                SyncStatus.syncing => (Icons.sync_rounded, 'Syncing…'),
                SyncStatus.offline => (
                    Icons.cloud_off_outlined,
                    'Offline — changes are queued'
                  ),
                SyncStatus.error => (
                    Icons.error_outline_rounded,
                    'Sync error — will retry'
                  ),
              };
              return ListTile(
                leading: Icon(icon),
                title: const Text('Automatic background sync'),
                subtitle: Text(
                  (sync?.pendingCount ?? 0) > 0
                      ? '$label · ${sync!.pendingCount} pending'
                      : label,
                ),
                onTap: () => ref.read(syncRepositoryProvider).syncNow(),
              );
            },
          ),
          _sectionHeader(context, 'Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('App lock'),
            subtitle: Text(switch (ref.watch(appLockControllerProvider).state.value.method) {
              AppLockMethod.biometric => 'Fingerprint / Face ID',
              AppLockMethod.pin => 'PIN',
              AppLockMethod.none => 'Off',
            }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _configureLock(context, ref),
          ),
          _sectionHeader(context, 'Accessibility'),
          SwitchListTile(
            secondary: const Icon(Icons.accessibility_new_rounded),
            title: const Text('OpenDyslexic font'),
            subtitle: const Text('A typeface designed for easier reading'),
            value: settings.fontFamily == 'OpenDyslexic',
            onChanged: (on) => ref.read(settingsProvider.notifier).update(
                  (x) => x.copyWith(
                      fontFamily: on ? 'OpenDyslexic' : 'Merriweather'),
                ),
          ),
          ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: const Text('Text size'),
            subtitle: Slider(
              value: settings.fontSizeSp,
              min: 12,
              max: 32,
              divisions: 20,
              label: '${settings.fontSizeSp.round()}',
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update((x) => x.copyWith(fontSizeSp: v)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _configureLock(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appLockControllerProvider);
    final choice = await showModalBottomSheet<AppLockMethod>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.fingerprint_rounded),
            title: const Text('Biometric (Face ID / fingerprint)'),
            onTap: () => Navigator.pop(ctx, AppLockMethod.biometric),
          ),
          ListTile(
            leading: const Icon(Icons.pin_rounded),
            title: const Text('PIN'),
            onTap: () => Navigator.pop(ctx, AppLockMethod.pin),
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_rounded),
            title: const Text('Off'),
            onTap: () => Navigator.pop(ctx, AppLockMethod.none),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == AppLockMethod.pin) {
      final pin = await _promptPin(context);
      if (pin == null) return;
      await controller.setMethod(AppLockMethod.pin, pin: pin);
    } else {
      await controller.setMethod(choice);
    }
  }

  Future<String?> _promptPin(BuildContext context) {
    final pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set a PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'At least 4 digits'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pinController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
        ),
      );
}
