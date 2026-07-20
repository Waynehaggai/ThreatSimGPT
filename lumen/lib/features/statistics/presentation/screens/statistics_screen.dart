import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../domain/entities/reading_stats.dart';

/// Reading statistics dashboard: streaks, hours, goals, and most-productive
/// reading hours — all driven by [readingStatsProvider].
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(readingStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reading stats')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load stats:\n$e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  label: 'Books completed',
                  value: '${stats.booksCompleted}',
                  icon: Icons.emoji_events_outlined,
                ),
                _StatCard(
                  label: 'Hours read',
                  value: _hoursLabel(stats),
                  icon: Icons.schedule_outlined,
                ),
                _StatCard(
                  label: 'Current streak',
                  value: '${stats.currentStreakDays}d',
                  icon: Icons.local_fire_department_outlined,
                ),
                _StatCard(
                  label: 'Pages read',
                  value: '${stats.pagesRead}',
                  icon: Icons.menu_book_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DailyGoalCard(stats: stats, ref: ref),
            const SizedBox(height: 16),
            _ProductiveHoursCard(stats: stats),
            const SizedBox(height: 16),
            _MetaCard(stats: stats),
          ],
        ),
      ),
    );
  }

  String _hoursLabel(ReadingStats s) {
    if (s.hoursRead >= 1) return '${s.hoursRead}';
    final minutes = s.secondsRead ~/ 60;
    return '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.stats, required this.ref});
  final ReadingStats stats;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = stats.dailyGoalMinutes;
    final done = stats.minutesToday;
    final progress = goal <= 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daily goal', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () => _editGoal(context),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            Text('$done / $goal min today', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context) async {
    var minutes = stats.dailyGoalMinutes;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily reading goal'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$minutes minutes / day'),
              Slider(
                value: minutes.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                label: '$minutes',
                onChanged: (v) => setState(() => minutes = v.round()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, minutes),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(statisticsRepositoryProvider).setDailyGoalMinutes(result);
    }
  }
}

class _ProductiveHoursCard extends StatelessWidget {
  const _ProductiveHoursCard({required this.stats});
  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = stats.minutesByHour.length == 24
        ? stats.minutesByHour
        : List<int>.filled(24, 0);
    final peak = hours.reduce((a, b) => a > b ? a : b);
    final peakHour = stats.peakHour;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most productive hours', style: theme.textTheme.titleMedium),
            if (peakHour != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Peak around ${_hourLabel(peakHour)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var h = 0; h < 24; h++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          height: peak <= 0 ? 2 : (hours[h] / peak * 76) + 2,
                          decoration: BoxDecoration(
                            color: hours[h] == 0
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('12a', style: theme.textTheme.labelSmall),
                Text('12p', style: theme.textTheme.labelSmall),
                Text('11p', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hourLabel(int h) {
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.stats});
  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(theme, 'Reading speed', '${stats.wordsPerMinute} wpm'),
            const Divider(),
            _row(theme, 'Longest streak', '${stats.longestStreakDays} days'),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
