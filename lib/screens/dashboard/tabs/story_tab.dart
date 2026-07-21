import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/screens/story/story_detail_screen.dart';
import 'package:my_app/services/story_service.dart';
import 'package:my_app/widgets/story/story_card.dart';
import 'package:my_app/widgets/story/story_section.dart';
import 'package:my_app/widgets/story/story_category_filter_menu.dart';
import 'package:my_app/widgets/story/story_time_filter_bar.dart';


class StoryTab extends StatefulWidget {
  const StoryTab({super.key});

  @override
  State<StoryTab> createState() => _StoryTabState();
}

class _StoryTabState extends State<StoryTab> {
  final _storyService = StoryService();
  late Future<List<StoryModel>> _storiesFuture;
  late Future<List<StoryModel>> _watchingFuture;

  String _selectedCategory = kAllCategories;
  StoryTimeFilter _timeFilter = StoryTimeFilter.all;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _storyService.fetchStories();
    _watchingFuture = _storyService.fetchWatching();
  }

  Future<void> _refresh() async {
    setState(() {
      _storiesFuture = _storyService.fetchStories();
      _watchingFuture = _storyService.fetchWatching();
    });
    await Future.wait([_storiesFuture, _watchingFuture]);
  }

  void _openStory(StoryModel story) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: story.id)))
        // Refresh when coming back -- the user may have liked/rated/
        // progressed the story, which should reflect immediately.
        .then((_) => _refresh());
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<StoryModel> _categoryFiltered(List<StoryModel> stories) {
    if (_selectedCategory == kAllCategories) return stories;
    return stories.where((s) => s.category == _selectedCategory).toList();
  }

  List<StoryModel> _timeAndCategoryFiltered(List<StoryModel> stories) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final source = _categoryFiltered(stories);

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

  List<String> _categoriesFrom(List<StoryModel> stories) {
    final categories = stories.map((s) => s.category).toSet().toList();
    categories.sort();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoryModel>>(
      future: _storiesFuture,
      builder: (context, storiesSnapshot) {
        if (storiesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (storiesSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('${storiesSnapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final stories = storiesSnapshot.data ?? const [];

        // "Recently Added" reflects the full library (not the
        // category/time filter below) -- it's a quick-access shelf,
        // not part of the filtered browse experience.
        final recentlyAdded = stories
            .where((s) => DateTime.now().difference(s.addedAt) <= const Duration(hours: 24))
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

        // The grid below respects both filters.
        final gridStories = [..._timeAndCategoryFiltered(stories)]
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      StoryCategoryFilterMenu(
                        categories: _categoriesFrom(stories),
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
                    onStoryTap: _openStory,
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<List<StoryModel>>(
                    future: _watchingFuture,
                    builder: (context, watchingSnapshot) {
                      // Errors here shouldn't block the whole tab --
                      // just show nothing until it succeeds.
                      final watching = watchingSnapshot.data ?? const [];
                      return StorySection(
                        title: 'story.watching'.tr(),
                        titleIcon: Icons.play_circle_outline,
                        stories: watching,
                        statIcon: Icons.hourglass_bottom,
                        statLabelBuilder: (s) => 'story.percent_watched'.tr(
                          namedArgs: {'percent': '${(s.watchProgress * 100).round()}'},
                        ),
                        onStoryTap: _openStory,
                      );
                    },
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
                          onTap: () => _openStory(story),
                        );
                      },
                      childCount: gridStories.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
