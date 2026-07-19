import 'package:flutter/material.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/data/dummy_stories.dart';
import 'package:my_app/widgets/story/story_section.dart';
import 'package:my_app/widgets/story/category_chip_bar.dart';

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

  List<StoryModel> get _filtered {
    if (_selectedCategory == 'All') return dummyStories;
    return dummyStories.where((s) => s.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stories = _filtered;

    // Each section = same stories, sorted a different way.
    final trending = [...stories]..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final recentlyAdded = [...stories]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final topRated = [...stories]..sort((a, b) => b.rating.compareTo(a.rating));
    final mostViewed = [...stories]..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final mostLiked = [...stories]..sort((a, b) => b.likeCount.compareTo(a.likeCount));
    final mostCommented = [...stories]..sort((a, b) => b.commentCount.compareTo(a.commentCount));

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
        else
          SliverList(
            delegate: SliverChildListDelegate([
              StorySection(
                title: '🔥 Trending Now',
                stories: trending,
                statIcon: Icons.visibility_outlined,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.viewCount)} views',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: '🆕 Recently Added',
                stories: recentlyAdded,
                statIcon: Icons.schedule,
                statLabelBuilder: (s) => _timeAgo(s.addedAt),
              ),
              const SizedBox(height: 24),
              StorySection(
                title: '⭐ Top Rated',
                stories: topRated,
                statIcon: Icons.star,
                statLabelBuilder: (s) => '${s.rating.toStringAsFixed(1)} / 5.0',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: '👁 Most Viewed',
                stories: mostViewed,
                statIcon: Icons.visibility_outlined,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.viewCount)} views',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: '❤️ Most Liked',
                stories: mostLiked,
                statIcon: Icons.favorite_border,
                statLabelBuilder: (s) => '${StoryModel.formatCount(s.likeCount)} likes',
              ),
              const SizedBox(height: 24),
              StorySection(
                title: '💬 Most Commented',
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
