import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/models/category_model.dart';
import 'package:my_app/screens/story/story_detail_screen.dart';
import 'package:my_app/services/story_service.dart';
import 'package:my_app/utils/date_range.dart';
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
  final _scrollController = ScrollController();
  static const int _pageSize = 20;

  // "All Stories" grid -- server-side paginated + filtered.
  final List<StoryModel> _gridStories = [];
  int _page = 1;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _loadingMore = false;
  Object? _gridError;

  // "Recently Added" shelf -- independent of the grid's filters below,
  // fetched with its own from/to (last 24h) so it's never truncated by
  // the grid's pagination.
  List<StoryModel> _recentlyAdded = [];
  bool _recentLoading = true;

  // "Watching" shelf.
  late Future<List<StoryModel>> _watchingFuture;

  // Full category list for the filter dropdown -- fetched once from
  // /categories, independent of which grid page is currently loaded.
  List<CategoryModel> _categories = [];

  String _selectedCategory = kAllCategories;
  StoryTimeFilter _timeFilter = StoryTimeFilter.all;

  @override
  void initState() {
    super.initState();
    _watchingFuture = _storyService.fetchWatching();
    _loadCategories();
    _loadRecentlyAdded();
    _loadGridInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _initialLoading) return;
    final threshold = _scrollController.position.maxScrollExtent - 400;
    if (_scrollController.position.pixels >= threshold) {
      _loadGridMore();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _storyService.fetchCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      // Not critical -- dropdown just shows "All" only if this fails.
    }
  }

  Future<void> _loadRecentlyAdded() async {
    setState(() => _recentLoading = true);
    try {
      final since = DateTime.now().subtract(const Duration(hours: 24));
      final result = await _storyService.fetchStoriesPaged(page: 1, limit: 50, from: since);
      if (!mounted) return;
      setState(() {
        _recentlyAdded = result.data;
        _recentLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _recentLoading = false);
    }
  }

  String? get _selectedCategoryId {
    if (_selectedCategory == kAllCategories) return null;
    final match = _categories.where((c) => c.name == _selectedCategory);
    return match.isEmpty ? null : match.first.id;
  }

  Future<void> _loadGridInitial() async {
    setState(() {
      _initialLoading = true;
      _gridError = null;
      _page = 1;
      _hasMore = true;
      _gridStories.clear();
    });
    try {
      final range = computeDateRange(_timeFilter.name);
      final result = await _storyService.fetchStoriesPaged(
        page: 1,
        limit: _pageSize,
        categoryId: _selectedCategoryId,
        from: range.from,
        to: range.to,
      );
      if (!mounted) return;
      setState(() {
        _gridStories.addAll(result.data);
        _hasMore = result.hasMore;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gridError = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadGridMore() async {
    setState(() => _loadingMore = true);
    try {
      final range = computeDateRange(_timeFilter.name);
      final nextPage = _page + 1;
      final result = await _storyService.fetchStoriesPaged(
        page: nextPage,
        limit: _pageSize,
        categoryId: _selectedCategoryId,
        from: range.from,
        to: range.to,
      );
      if (!mounted) return;
      setState(() {
        _gridStories.addAll(result.data);
        _hasMore = result.hasMore;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      // Don't wipe what's already on screen -- just stop; scrolling up
      // and back down will retry.
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _watchingFuture = _storyService.fetchWatching());
    await Future.wait([
      _loadCategories(),
      _loadRecentlyAdded(),
      _loadGridInitial(),
      _watchingFuture,
    ]);
  }

  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
    _loadGridInitial();
  }

  void _onTimeFilterChanged(StoryTimeFilter filter) {
    setState(() => _timeFilter = filter);
    _loadGridInitial();
  }

  void _openStory(StoryModel story) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: story.id)))
        .then((_) => _refresh());
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return 'story.days_ago'.tr(namedArgs: {'count': '${diff.inDays}'});
    if (diff.inHours > 0) return 'story.hours_ago'.tr(namedArgs: {'count': '${diff.inHours}'});
    return 'story.minutes_ago'.tr(namedArgs: {'count': '${diff.inMinutes}'});
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gridError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text('$_gridError', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadGridInitial, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final categoryNames = _categories.map((c) => c.name).toList()..sort();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  StoryCategoryFilterMenu(
                    categories: categoryNames,
                    selected: _selectedCategory,
                    onChanged: _onCategoryChanged,
                  ),
                  Expanded(
                    child: StoryTimeFilterBar(
                      selected: _timeFilter,
                      onSelected: _onTimeFilterChanged,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              if (!_recentLoading && _recentlyAdded.isNotEmpty)
                StorySection(
                  title: 'story.recently_added'.tr(),
                  titleIcon: Icons.fiber_new_outlined,
                  stories: _recentlyAdded,
                  statIcon: Icons.schedule,
                  statLabelBuilder: (s) => _timeAgo(s.addedAt),
                  autoScroll: true,
                  onStoryTap: _openStory,
                ),
              const SizedBox(height: 24),
              FutureBuilder<List<StoryModel>>(
                future: _watchingFuture,
                builder: (context, watchingSnapshot) {
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
          if (_gridStories.isEmpty)
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
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.48,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final story = _gridStories[index];
                    return StoryCard(
                      story: story,
                      statLabel: '${story.rating.toStringAsFixed(1)} / 5.0',
                      statIcon: Icons.star,
                      onTap: () => _openStory(story),
                    );
                  },
                  childCount: _gridStories.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox(height: 20),
            ),
          ],
        ],
      ),
    );
  }
}
