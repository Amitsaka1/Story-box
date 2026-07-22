import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/screens/story/story_detail_screen.dart';
import 'package:my_app/services/story_service.dart';
import 'package:my_app/widgets/story/story_card.dart';

/// Real "recently viewed" history, backed by GET /stories/history --
/// server-side paginated infinite scroll, most recently viewed first.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _storyService = StoryService();
  final _scrollController = ScrollController();
  static const int _pageSize = 20;

  final List<StoryModel> _stories = [];
  int _page = 1;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
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
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _stories.clear();
    });
    try {
      final result = await _storyService.fetchHistoryPaged(page: 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _stories.addAll(result.data);
        _hasMore = result.hasMore;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await _storyService.fetchHistoryPaged(page: nextPage, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _stories.addAll(result.data);
        _hasMore = result.hasMore;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return 'story.days_ago'.tr(namedArgs: {'count': '${diff.inDays}'});
    if (diff.inHours > 0) return 'story.hours_ago'.tr(namedArgs: {'count': '${diff.inHours}'});
    return 'story.minutes_ago'.tr(namedArgs: {'count': '${diff.inMinutes}'});
  }

  void _openStory(StoryModel story) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: story.id)))
        .then((_) => _loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: colorScheme.outline),
              const SizedBox(height: 12),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadInitial, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'history.recently_viewed'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_stories.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_outlined, size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('history.no_history_title'.tr(), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'history.no_history_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
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
                    final story = _stories[index];
                    return StoryCard(
                      story: story,
                      statLabel: _timeAgo(story.viewedAt ?? story.addedAt),
                      statIcon: Icons.visibility_outlined,
                      onTap: () => _openStory(story),
                    );
                  },
                  childCount: _stories.length,
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
