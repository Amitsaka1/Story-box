import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/screens/settings_screen.dart';

/// Pure UI widget -- shows the current section title on the left and a
/// settings icon on the right. Tapping the settings icon pushes
/// SettingsScreen on top of the dashboard, so the bottom nav / tab
/// state stays intact underneath when the user comes back.
///
/// [onTrendingTap] is optional -- when provided (only on the Story
/// tab), a Trending icon is shown between the title and settings.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onTrendingTap;

  const DashboardAppBar({super.key, required this.title, this.onTrendingTap});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      centerTitle: false,
      actions: [
        if (onTrendingTap != null)
          IconButton(
            icon: const Icon(Icons.local_fire_department_outlined),
            tooltip: 'dashboard.trending_tooltip'.tr(),
            onPressed: onTrendingTap,
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'dashboard.settings_tooltip'.tr(),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
