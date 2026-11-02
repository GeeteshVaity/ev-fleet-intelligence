import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/presentation/providers/notification_providers.dart';
import 'router/route_names.dart';
import 'theme/app_colors.dart';

/// Bottom-navigation shell wrapping the four main tabs.
///
/// Tabs keep their own navigation stack (`StatefulShellRoute`), and the
/// unread-notification badge on the Profile tab is driven by Riverpod.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: const _ShellNavigationBar(),
    );
  }
}

class _ShellNavigationBar extends ConsumerWidget {
  const _ShellNavigationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = GoRouterState.of(context).navigationShell;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Tapping the active tab returns it to its root.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: _ProfileIcon(
              showBadge: unreadCount > 0,
              icon: Icons.person_outline_rounded,
            ),
            selectedIcon: _ProfileIcon(
              showBadge: unreadCount > 0,
              icon: Icons.person_rounded,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.icon, required this.showBadge});

  final IconData icon;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return Icon(icon);
    return Badge(
      backgroundColor: AppColors.danger,
      smallSize: 8,
      child: Icon(icon),
    );
  }
}

/// Convenience: the tab index of a route path.
int shellTabIndexFor(String path) {
  for (var i = 0; i < RoutePaths.shellTabs.length; i++) {
    if (RoutePaths.shellTabs[i] == path) return i;
  }
  return 0;
}
