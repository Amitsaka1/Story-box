import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
/// Pure UI widget -- no business logic here.
/// Parent (DashboardScreen) owns the selected index and passes it in,
/// this widget only renders and reports taps back via [onTap].
class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DashboardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 3,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.auto_stories_outlined),
          selectedIcon: const Icon(Icons.auto_stories),
          label: 'dashboard.story_tab'.tr(),
        ),
        NavigationDestination(
          icon: const Icon(Icons.movie_creation_outlined),
          selectedIcon: const Icon(Icons.movie_creation),
          label: 'dashboard.documentary_tab'.tr(),
        ),
        NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history),
          label: 'dashboard.history_tab'.tr(),
        ),
        NavigationDestination(
          icon: const Icon(Icons.workspace_premium_outlined),
          selectedIcon: const Icon(Icons.workspace_premium),
          label: 'dashboard.subscription_tab'.tr(),
        ),
      ],
    );
  }
}
