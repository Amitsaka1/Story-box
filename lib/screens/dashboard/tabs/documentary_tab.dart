import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/services/documentary_service.dart';
import 'package:my_app/utils/date_range.dart';
import 'package:my_app/widgets/documentary/documentary_card.dart';
import 'package:my_app/widgets/documentary/documentary_time_filter_bar.dart';
import 'package:my_app/widgets/documentary/documentary_sort_menu.dart';

/// Documentary dashboard: time-range chips (All / Today / Yesterday /
/// This Week / This Month / This Year) + a sort dropdown (Popular /
/// Rating / Likes / Comments / Views). Server-side paginated + filtered
/// infinite scroll -- changing sort or time filter resets to page 1
/// and re-fetches from the backend with that filter applied.
class DocumentaryTab extends StatefulWidget {
  const DocumentaryTab({super.key});

  @override
  State<DocumentaryTab> createState() => _DocumentaryTabState();
}

class _DocumentaryTabState extends State<DocumentaryTab> {
  final _documentaryService = DocumentaryService();
  final _scrollController = ScrollController();
  static const int _pageSize = 20;

  final List<DocumentaryModel> _documentaries = [];
  int _page = 1;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _loadingMore = false;
  Object? _error;

  DocumentaryTimeFilter _timeFilter = DocumentaryTimeFilter.all;
  DocumentarySortOption _sort = DocumentarySortOption.popularity;

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
      _documentaries.clear();
    });
    try {
      final range = computeDateRange(_timeFilter.name);
      final result = await _documentaryService.fetchDocumentariesPaged(
        page: 1,
        limit: _pageSize,
        sort: _sort.name,
        from: range.from,
        to: range.to,
      );
      if (!mounted) return;
      setState(() {
        _documentaries.addAll(result.data);
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
      final range = computeDateRange(_timeFilter.name);
      final nextPage = _page + 1;
      final result = await _documentaryService.fetchDocumentariesPaged(
        page: nextPage,
        limit: _pageSize,
        sort: _sort.name,
        from: range.from,
        to: range.to,
      );
      if (!mounted) return;
      setState(() {
        _documentaries.addAll(result.data);
        _hasMore = result.hasMore;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() => _loadInitial();

  void _onSortChanged(DocumentarySortOption sort) {
    setState(() {
      // Tapping the already-active sort option again clears back to
      // the default (Popular) -- same behavior as before.
      _sort = (sort == _sort) ? DocumentarySortOption.popularity : sort;
    });
    _loadInitial();
  }

  void _onTimeFilterChanged(DocumentaryTimeFilter filter) {
    setState(() => _timeFilter = filter);
    _loadInitial();
  }

  String _statFor(DocumentaryModel d) {
    switch (_sort) {
      case DocumentarySortOption.popularity:
        return 'documentary.stat_popularity'.tr(namedArgs: {
          'rating': d.rating.toStringAsFixed(1),
          'views': DocumentaryModel.formatCount(d.viewCount),
        });
      case DocumentarySortOption.rating:
        return 'documentary.stat_rating'.tr(namedArgs: {'rating': d.rating.toStringAsFixed(1)});
      case DocumentarySortOption.likes:
        return 'documentary.stat_likes'.tr(namedArgs: {'count': DocumentaryModel.formatCount(d.likeCount)});
      case DocumentarySortOption.comments:
        return 'documentary.stat_comments'.tr(namedArgs: {'count': DocumentaryModel.formatCount(d.commentCount)});
      case DocumentarySortOption.views:
        return 'documentary.stat_views'.tr(namedArgs: {'count': DocumentaryModel.formatCount(d.viewCount)});
    }
  }

  IconData get _statIcon {
    switch (_sort) {
      case DocumentarySortOption.popularity:
        return Icons.local_fire_department_outlined;
      case DocumentarySortOption.rating:
        return Icons.star_outline;
      case DocumentarySortOption.likes:
        return Icons.favorite_border;
      case DocumentarySortOption.comments:
        return Icons.mode_comment_outlined;
      case DocumentarySortOption.views:
        return Icons.visibility_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
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
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  DocumentarySortMenu(selected: _sort, onChanged: _onSortChanged),
                  Expanded(
                    child: DocumentaryTimeFilterBar(selected: _timeFilter, onSelected: _onTimeFilterChanged),
                  ),
                ],
              ),
            ),
          ),
          if (_documentaries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.movie_creation_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'documentary.no_documentaries_filter'.tr(namedArgs: {'filter': _timeFilter.label}),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.48,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final d = _documentaries[index];
                    return DocumentaryCard(documentary: d, statLabel: _statFor(d), statIcon: _statIcon);
                  },
                  childCount: _documentaries.length,
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
