import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';

/// Bottom-navigation shell hosting the primary destinations. The reader opens
/// above this shell (full-screen), keeping navigation state intact underneath.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    (Routes.library, Icons.local_library_outlined, Icons.local_library,
        'Library'),
    (Routes.statistics, Icons.insights_outlined, Icons.insights, 'Stats'),
    (Routes.settings, Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  int _indexFor(String location) {
    final i = _destinations.indexWhere((d) => location.startsWith(d.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_destinations[i].$1),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$2),
              selectedIcon: Icon(d.$3),
              label: d.$4,
            ),
        ],
      ),
    );
  }
}
