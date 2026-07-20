import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/data/dummy_stories.dart';
import 'package:my_app/widgets/story/story_card.dart';
import 'package:my_app/widgets/story/story_section.dart';
import 'package:my_app/widgets/story/story_category_filter_menu.dart';
import 'package:my_app/widgets/story/story_time_filter_bar.dart';

/// Story dashboard: category icon-filter + time chips up top, then
/// "Recently Added" and "Watching" horizontal sections, then every
/// matching story in a 3-column grid underneath. Trending has moved
/// to its own full "Top 20" screen (see TrendingScreen), reached via
/// the app bar icon -- it's no longer a section on this page.
class StoryTab extends StatefulWidget {
  const StoryTab({super.key});

  @override
  State<StoryTab> createState() => _StoryTabState();
}

class _StoryTabState extends State<StoryTab> {
  String _selectedCategory = kAllCategories;
  StoryTimeFilter _timeFilter = StoryTimeFilter.all;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<StoryModel> get _categoryFiltered {
    if (_selectedCategory == kAllCategories) return dummyStories;
    return dummyStories.where((s) => s.category == _selectedCategory).toList();
  }

  List<StoryModel> get _timeAndCategoryFiltered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final source = _categoryFiltered;

    switch (_timeFilter) {
      case StoryTimeFilter.all:
        return source;
      case StoryTimeFilter.today:
        return source.where((s) => _isSameDay(s.addedAt, today)).toList();
      case StoryTimeFilter.yesterday:
        return source.where((s) => _isSameDay(s.addedAt, yesterday)).toList();
      case StoryTimeFilter.thisWeek:
        final weekStart = today.subtract(const Duration(days: 6));
        return source.where((s) => !s.addedAt.isBefore(weekStart)).toList();
      case StoryTimeFilter.thisMonth:
        return source.where((s) => s.addedAt.year == now.year && s.addedAt.month == now.month).toList();
      case StoryTimeFilter.thisYear:
        return source.where((s) => s.addedAt.year == now.year).toList();
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return 'story.days_ago'.tr(namedArgs: {'count': '${diff.inDays}'});
    if (diff.inHours > 0) return 'story.hours_ago'.tr(namedArgs: {'count': '${diff.inHours}'});
    return 'story.minutes_ago'.tr(namedArgs: {'count': '${diff.inMinutes}'});
  }

  @override
  Widget build(BuildContext context) {
    // "Recently Added" and "Watching" always reflect the full library
    // (not the category/time filter below) -- they're quick-access
    // shelves, not part of the filtered browse experience.
    final recentlyAdded = dummyStories
        .where((s) => DateTime.now().difference(s.addedAt) <= const Duration(hours: 24))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    final watching = dummyStories.where((s) => s.isWatching).toList();

    // The grid below respects both filters.
    final gridStories = [..._timeAndCategoryFiltered]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                StoryCategoryFilterMenu(
                  categories: storyCategories,
                  selected: _selectedCategory,
                  onChanged: (category) => setState(() => _selectedCategory = category),
                ),
                Expanded(
                  child: StoryTimeFilterBar(
                    selected: _timeFilter,
                    onSelected: (filter) => setState(() => _timeFilter = filter),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            StorySection(
              title: 'story.recently_added'.tr(),
              titleIcon: Icons.fiber_new_outlined,
              stories: recentlyAdded,
              statIcon: Icons.schedule,
              statLabelBuilder: (s) => _timeAgo(s.addedAt),
              autoScroll: true,
            ),
            const SizedBox(height: 24),
            StorySection(
              title: 'story.watching'.tr(),
              titleIcon: Icons.play_circle_outline,
              stories: watching,
              statIcon: Icons.hourglass_bottom,
              statLabelBuilder: (s) => 'story.percent_watched'.tr(
                namedArgs: {'percent': '${(s.watchProgress * 100).round()}'},
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              _selectedCategory == kAllCategories ? 'story.all_stories'.tr() : _selectedCategory,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (gridStories.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'story.no_stories_filter'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.48,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final story = gridStories[index];
                  return StoryCard(
                    story: story,
                    statLabel: '${story.rating.toStringAsFixed(1)} / 5.0',
                    statIcon: Icons.star,
                  );
                },
                childCount: gridStories.length,
              ),
            ),
          ),
      ],
    );
  }
}
