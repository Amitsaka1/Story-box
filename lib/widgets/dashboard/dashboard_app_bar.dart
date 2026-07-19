import 'package:flutter/material.dart';
import 'package:my_app/screens/settings_screen.dart';

/// Pure UI widget -- shows the current section title on the left and a
/// settings icon on the right. Tapping the icon pushes SettingsScreen on
/// top of the dashboard, so the bottom nav / tab state stays intact
/// underneath when the user comes back.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const DashboardAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
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
