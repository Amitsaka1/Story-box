import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/data/dummy_stories.dart';
import 'package:my_app/widgets/story/story_card.dart';
import 'package:my_app/widgets/story/story_category_filter_menu.dart';

/// Full-screen "Top 20" view -- ranked by popularity score. With no
/// category selected it shows the overall top 20 across every story;
/// picking a category re-ranks and shows that category's own top 20.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  String _selectedCategory = kAllCategories;
  static const int _limit = 20;

  List<StoryModel> get _topStories {
    final source = _selectedCategory == kAllCategories
        ? dummyStories
        : dummyStories.where((s) => s.category == _selectedCategory).toList();

    final sorted = [...source]..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    return sorted.take(_limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stories = _topStories;

    return Scaffold(
      appBar: AppBar(
        title: Text('story.top20_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 16, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  StoryCategoryFilterMenu(
                    categories: storyCategories,
                    selected: _selectedCategory,
                    onChanged: (category) => setState(() => _selectedCategory = category),
                  ),
                  Text(
                    _selectedCategory == kAllCategories ? 'story.all_categories'.tr() : _selectedCategory,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (stories.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'story.no_stories_category'.tr(namedArgs: {'category': _selectedCategory}),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.48,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final story = stories[index];
                    return Stack(
                      children: [
                        StoryCard(
                          story: story,
                          statLabel: '${StoryModel.formatCount(story.viewCount)} views',
                          statIcon: Icons.visibility_outlined,
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: stories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
