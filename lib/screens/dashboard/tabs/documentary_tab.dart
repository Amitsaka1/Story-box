import 'package:flutter/material.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/data/dummy_documentaries.dart';
import 'package:my_app/widgets/documentary/documentary_card.dart';
import 'package:my_app/widgets/documentary/documentary_time_filter_bar.dart';
import 'package:my_app/widgets/documentary/documentary_sort_menu.dart';

/// Documentary dashboard: time-range chips (All / Today / Yesterday /
/// This Week / This Month / This Year) + a sort dropdown (Popular /
/// Rating / Likes / Comments / Views), rendered as a 3-column grid.
///
/// The time buckets are calculated live from each documentary's
/// addedAt every time this builds -- there's no manual "move it to
/// yesterday" step. A documentary added 20 hours ago is "Today" right
/// now; the moment the calendar date changes, the exact same
/// addedAt value naturally falls into "Yesterday" / "This Week" on
/// its own the next time the UI builds.
class DocumentaryTab extends StatefulWidget {
  const DocumentaryTab({super.key});

  @override
  State<DocumentaryTab> createState() => _DocumentaryTabState();
}

class _DocumentaryTabState extends State<DocumentaryTab> {
  DocumentaryTimeFilter _timeFilter = DocumentaryTimeFilter.all;
  DocumentarySortOption _sort = DocumentarySortOption.popularity;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DocumentaryModel> get _timeFiltered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    switch (_timeFilter) {
      case DocumentaryTimeFilter.all:
        return dummyDocumentaries;
      case DocumentaryTimeFilter.today:
        return dummyDocumentaries.where((d) => _isSameDay(d.addedAt, today)).toList();
      case DocumentaryTimeFilter.yesterday:
        return dummyDocumentaries.where((d) => _isSameDay(d.addedAt, yesterday)).toList();
      case DocumentaryTimeFilter.thisWeek:
        final weekStart = today.subtract(const Duration(days: 6));
        return dummyDocumentaries.where((d) => !d.addedAt.isBefore(weekStart)).toList();
      case DocumentaryTimeFilter.thisMonth:
        return dummyDocumentaries
            .where((d) => d.addedAt.year == now.year && d.addedAt.month == now.month)
            .toList();
      case DocumentaryTimeFilter.thisYear:
        return dummyDocumentaries.where((d) => d.addedAt.year == now.year).toList();
    }
  }

  List<DocumentaryModel> get _sorted {
    final list = [..._timeFiltered];
    switch (_sort) {
      case DocumentarySortOption.popularity:
        list.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
        break;
      case DocumentarySortOption.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case DocumentarySortOption.likes:
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
      case DocumentarySortOption.comments:
        list.sort((a, b) => b.commentCount.compareTo(a.commentCount));
        break;
      case DocumentarySortOption.views:
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
    }
    return list;
  }

  String _statFor(DocumentaryModel d) {
    switch (_sort) {
      case DocumentarySortOption.popularity:
        return '${d.rating.toStringAsFixed(1)} · ${DocumentaryModel.formatCount(d.viewCount)} views';
      case DocumentarySortOption.rating:
        return '${d.rating.toStringAsFixed(1)} / 5.0';
      case DocumentarySortOption.likes:
        return '${DocumentaryModel.formatCount(d.likeCount)} likes';
      case DocumentarySortOption.comments:
        return '${DocumentaryModel.formatCount(d.commentCount)} comments';
      case DocumentarySortOption.views:
        return '${DocumentaryModel.formatCount(d.viewCount)} views';
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
    final documentaries = _sorted;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: DocumentaryTimeFilterBar(
                    selected: _timeFilter,
                    onSelected: (filter) => setState(() => _timeFilter = filter),
                  ),
                ),
                DocumentarySortMenu(
                  selected: _sort,
                  onChanged: (sort) => setState(() => _sort = sort),
                ),
              ],
            ),
          ),
        ),
        if (documentaries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No documentaries in "${_timeFilter.label}"',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
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
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final d = documentaries[index];
                  return DocumentaryCard(
                    documentary: d,
                    statLabel: _statFor(d),
                    statIcon: _statIcon,
                  );
                },
                childCount: documentaries.length,
              ),
            ),
          ),
      ],
    );
  }
}
