import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/reading_stats.dart';

/// Placeholder stats source; replaced by `StatisticsRepository.watchStats()`.
final statsProvider = Provider<ReadingStats>((_) => const ReadingStats());

/// Reading statistics dashboard: streaks, hours, goals, productive hours.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reading stats')),
      body: ListView(
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
                  icon: Icons.emoji_events_outlined),
              _StatCard(
                  label: 'Hours read',
                  value: '${stats.hoursRead}',
                  icon: Icons.schedule_outlined),
              _StatCard(
                  label: 'Current streak',
                  value: '${stats.currentStreakDays}d',
                  icon: Icons.local_fire_department_outlined),
              _StatCard(
                  label: 'Pages read',
                  value: '${stats.pagesRead}',
                  icon: Icons.menu_book_outlined),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily goal', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text('0 / ${stats.dailyGoalMinutes} min today',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.icon});

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
            Text(value,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
