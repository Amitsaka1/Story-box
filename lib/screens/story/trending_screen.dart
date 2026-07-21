import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/screens/story/story_detail_screen.dart';
import 'package:my_app/services/story_service.dart';
import 'package:my_app/widgets/story/story_card.dart';
import 'package:my_app/widgets/story/story_category_filter_menu.dart';

/// Full-screen "Top 20" view -- ranked by popularity score. With no
/// category selected it shows the overall top 20 across every story;
/// picking a category re-ranks and shows that category's own top 20.
///
/// Stories come from the backend (GET /stories) instead of dummy data.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  final _storyService = StoryService();
  late Future<List<StoryModel>> _storiesFuture;

  String _selectedCategory = kAllCategories;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _storyService.fetchStories();
  }

  List<StoryModel> _topStories(List<StoryModel> stories) {
    final source = _selectedCategory == kAllCategories
        ? stories
        : stories.where((s) => s.category == _selectedCategory).toList();

    final sorted = [...source]..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    return sorted.take(_limit).toList();
  }

  List<String> _categoriesFrom(List<StoryModel> stories) {
    final categories = stories.map((s) => s.category).toSet().toList();
    categories.sort();
    return categories;
  }

  void _openStory(StoryModel story) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: story.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('story.top20_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<StoryModel>>(
        future: _storiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final allStories = snapshot.data ?? const [];
          final stories = _topStories(allStories);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 16, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      StoryCategoryFilterMenu(
                        categories: _categoriesFrom(allStories),
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
                              onTap: () => _openStory(story),
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
          );
        },
      ),
    );
  }
}
