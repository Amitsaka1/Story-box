import 'package:flutter/material.dart';
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

  static const _titles = ['Story', 'Documentary', 'History', 'Subscription'];

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

  @override
  Widget build(BuildContext context) {
    // Trending icon only makes sense on the Story tab (index 0).
    final isStoryTab = _selectedIndex == 0;

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
      bottomNavigationBar: DashboardBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
