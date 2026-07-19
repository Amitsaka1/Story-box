import 'package:flutter/material.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/data/dummy_stories.dart';
import 'package:my_app/widgets/story/story_section.dart';
import 'package:my_app/widgets/story/category_chip_bar.dart';
import 'package:my_app/widgets/story/story_card.dart';

/// Advanced Story dashboard: category filter up top, then multiple
/// horizontal sections (Trending, Recently Added, Top Rated, Most
/// Viewed, Most Liked, Most Commented). Filtering by category re-runs
/// all the sort logic below on just the matching stories.
class StoryTab extends StatefulWidget {
  const StoryTab({super.key});

  @override
  State<StoryTab> createState() => _StoryTabState();
}

class _StoryTabState extends State<StoryTab> {
  String _selectedCategory = 'All';

  // Ranked sections (Trending, Top Rated, etc.) never show more than this
  // many cards -- keeps each row scannable instead of endless.
  static const int _rankedSectionLimit = 10;

  // "Recently Added" only counts stories added within this window.
  // A story that was added yesterday and nothing new came in today will
  // naturally disappear from this section once it falls outside 24h --
  // no manual cleanup needed, it's just a filter on addedAt.
  static const Duration _recentWindow = Duration(hours: 24);

  List<StoryModel> get _filtered {
    if (_selectedCategory == 'All') return dummyStories;
    return dummyStories.where((s) => s.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stories = _filtered;
    final now = DateTime.now();

    // Each ranked section = same stories, sorted a different way, capped at 10.
    final trending = ([...stories]..sort((a, b) => b.viewCount.compareTo(a.viewCount)))
        .take(_rankedSectionLimit)
        .toList();
    final topRated = ([...stories]..sort((a, b) => b.rating.compareTo(a.rating)))
        .take(_rankedSectionLimit)
        .toList();
    final mostViewed = ([...stories]..sort((a, b) => b.viewCount.compareTo(a.viewCount)))
        .take(_rankedSectionLimit)
        .toList();
    final mostLiked = ([...stories]..sort((a, b) => b.likeCount.compareTo(a.likeCount)))
        .take(_rankedSectionLimit)
        .toList();
    final mostCommented = ([...stories]..sort((a, b) => b.commentCount.compareTo(a.commentCount)))
        .take(_rankedSectionLimit)
        .toList();

    // Recently Added: no cap on count, but only stories added in the
    // last 24 hours qualify -- so it auto-empties (and the section
    // auto-hides, see StorySection) if nothing new was uploaded today.
    final recentlyAdded = stories.where((s) => now.difference(s.addedAt) <= _recentWindow).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
          sliver: SliverToBoxAdapter(
            child: CategoryChipBar(
              categories: storyCategories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
          ),
        ),
        if (stories.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No stories in "$_selectedCategory" yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else if (_selectedCategory != 'All')
          // A specific category is selected -- skip all the ranked
          // sections and just show every matching story in a simple
          // 3-column grid.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final story = stories[index];
                  return StoryCard(
                    story: story,
                    statLabel: '${story.rating.toStringAsFixed(1)} / 5.0',
                    statIcon: Icons.star,
                  );
                },
                childCount: stories.length,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildListDelegate([
              StorySection(
                title: 'Trending Now',
                titleIcon: Icons.local_fire_department,
                stories: trending,
                statIcon: Icons.visibility_outlined,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.viewCount)} views',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: 'Recently Added',
                titleIcon: Icons.fiber_new_outlined,
                stories: recentlyAdded,
                statIcon: Icons.schedule,
                statLabelBuilder: (s) => _timeAgo(s.addedAt),
              ),
              const SizedBox(height: 24),
              StorySection(
                title: 'Top Rated',
                titleIcon: Icons.star_outline,
                stories: topRated,
                statIcon: Icons.star,
                statLabelBuilder: (s) => '${s.rating.toStringAsFixed(1)} / 5.0',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: 'Most Viewed',
                titleIcon: Icons.visibility_outlined,
                stories: mostViewed,
                statIcon: Icons.visibility_outlined,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.viewCount)} views',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: 'Most Liked',
                titleIcon: Icons.favorite_border,
                stories: mostLiked,
                statIcon: Icons.favorite_border,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.likeCount)} likes',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: 'Most Commented',
                titleIcon: Icons.mode_comment_outlined,
                stories: mostCommented,
                statIcon: Icons.mode_comment_outlined,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.commentCount)} comments',
              ),
              const SizedBox(height: 24),
            ]),
          ),
      ],
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
