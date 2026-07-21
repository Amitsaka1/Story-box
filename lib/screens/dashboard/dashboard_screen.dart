import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/providers/auth_provider.dart';
import 'package:my_app/screens/admin/add_content_screen.dart';
import 'package:my_app/widgets/dashboard/dashboard_app_bar.dart';
import 'package:my_app/widgets/dashboard/dashboard_bottom_nav.dart';
import 'package:my_app/screens/story/trending_screen.dart';
import 'tabs/story_tab.dart';
import 'tabs/documentary_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/subscription_tab.dart';

/// Main dashboard shell. Owns ONLY the "which tab is selected" state
/// (navigation logic) -- the actual tab UIs live in their own files
/// under tabs/, and the app bar / bottom nav are their own widgets too.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  List<String> get _titles => [
        'dashboard.story_tab'.tr(),
        'dashboard.documentary_tab'.tr(),
        'dashboard.history_tab'.tr(),
        'dashboard.subscription_tab'.tr(),
      ];
  
  static const _tabs = [
    StoryTab(),
    DocumentaryTab(),
    HistoryTab(),
    SubscriptionTab(),
  ];

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openTrending() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrendingScreen()),
    );
  }

  void _openAddContent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddContentScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Trending icon only makes sense on the Story tab (index 0).
    final isStoryTab = _selectedIndex == 0;

    // Add-content FAB only shows for admins, and only on the Story /
    // Documentary tabs (index 0/1) -- it doesn't make sense on
    // History or Subscription.
    final isAdmin = context.watch<AuthProvider>().currentUser?.isAdmin ?? false;
    final isContentTab = _selectedIndex == 0 || _selectedIndex == 1;

    return Scaffold(
      appBar: DashboardAppBar(
        title: _titles[_selectedIndex],
        onTrendingTap: isStoryTab ? _openTrending : null,
      ),
      // IndexedStack keeps each tab's scroll position / state alive
      // when switching between tabs, instead of rebuilding from scratch.
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      floatingActionButton: (isAdmin && isContentTab)
          ? FloatingActionButton.extended(
              onPressed: _openAddContent,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      bottomNavigationBar: DashboardBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
