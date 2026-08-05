import 'package:flutter/material.dart';
import 'package:my_app/core/local_cache.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/screens/documentary/documentary_detail_screen.dart';
import 'package:my_app/screens/story/story_detail_screen.dart';
import 'package:my_app/services/documentary_service.dart';
import 'package:my_app/services/story_service.dart';

enum _HistorySection { watching, complete }

/// A single row shown in either section -- wraps either a StoryModel or
/// a DocumentaryModel so both types render in one merged, sorted list.
class _HistoryItem {
  final String id;
  final String title;
  final String coverImageUrl;
  final double watchProgress;
  final DateTime lastWatchedAt;
  final bool isStory;

  const _HistoryItem({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.watchProgress,
    required this.lastWatchedAt,
    required this.isStory,
  });

  factory _HistoryItem.fromStory(StoryModel s) => _HistoryItem(
        id: s.id,
        title: s.title,
        coverImageUrl: s.coverImageUrl,
        watchProgress: s.watchProgress,
        lastWatchedAt: s.lastWatchedAt ?? s.addedAt,
        isStory: true,
      );

  factory _HistoryItem.fromDocumentary(DocumentaryModel d) => _HistoryItem(
        id: d.id,
        title: d.title,
        coverImageUrl: d.coverImageUrl,
        watchProgress: d.watchProgress,
        lastWatchedAt: d.lastWatchedAt ?? d.addedAt,
        isStory: false,
      );

  /// Used to persist the merged, already-sorted list into LocalCache.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'coverImageUrl': coverImageUrl,
        'watchProgress': watchProgress,
        'lastWatchedAt': lastWatchedAt.toIso8601String(),
        'isStory': isStory,
      };

  factory _HistoryItem.fromCacheJson(Map<String, dynamic> json) => _HistoryItem(
        id: json['id'] as String,
        title: json['title'] as String,
        coverImageUrl: json['coverImageUrl'] as String,
        watchProgress: (json['watchProgress'] as num).toDouble(),
        lastWatchedAt: DateTime.parse(json['lastWatchedAt'] as String),
        isStory: json['isStory'] as bool,
      );
}
/// History: two sections -- Watching (started but not finished) and
/// Complete (finished, per the ongoing/completed business rule) --
/// each merging Story + Documentary together, most recent first.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _storyService = StoryService();
  final _documentaryService = DocumentaryService();

  _HistorySection _section = _HistorySection.watching;
  List<_HistoryItem> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(useCache: true);
  }

  String get _cacheKey => 'history_${_section.name}';

  Future<void> _load({bool useCache = false}) async {
    if (useCache) {
      final cached = LocalCache.read(_cacheKey);
      if (cached != null) {
        try {
          final cachedItems =
              (cached as List).map((j) => _HistoryItem.fromCacheJson(j as Map<String, dynamic>)).toList();
          setState(() {
            _items = cachedItems;
            _loading = false;
          });
        } catch (_) {
          // Old/corrupt cache shape -- ignore, fresh fetch below still runs.
        }
      }
    }

    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });

    try {
      final List<StoryModel> stories;
      final List<DocumentaryModel> documentaries;

      if (_section == _HistorySection.watching) {
        final results = await Future.wait([_storyService.fetchWatching(), _documentaryService.fetchWatching()]);
        stories = results[0] as List<StoryModel>;
        documentaries = results[1] as List<DocumentaryModel>;
      } else {
        final results = await Future.wait([_storyService.fetchCompleted(), _documentaryService.fetchCompleted()]);
        stories = results[0] as List<StoryModel>;
        documentaries = results[1] as List<DocumentaryModel>;
      }

      final freshItems = [
        ...stories.map(_HistoryItem.fromStory),
        ...documentaries.map(_HistoryItem.fromDocumentary),
      ];
      freshItems.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

      if (!mounted) return;
      setState(() {
        _items = freshItems;
        _loading = false;
      });
      LocalCache.save(_cacheKey, freshItems.map((i) => i.toJson()).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_items.isEmpty) _error = e;
        _loading = false;
      });
    }
  }

  void _onSectionChanged(Set<_HistorySection> selection) {
    setState(() => _section = selection.first);
    _load(useCache: true);
  }

  void _openItem(_HistoryItem item) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => item.isStory
              ? StoryDetailScreen(storyId: item.id)
              : DocumentaryDetailScreen(documentaryId: item.id),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => setState(() => _itemsFuture = _load()),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SegmentedButton<_HistorySection>(
                segments: const [
                  ButtonSegment(value: _HistorySection.watching, label: Text('Watching'), icon: Icon(Icons.play_circle_outline)),
                  ButtonSegment(value: _HistorySection.complete, label: Text('Complete'), icon: Icon(Icons.check_circle_outline)),
                ],
                selected: {_section},
                onSelectionChanged: _onSectionChanged,
              ),
            ),
          ),
          FutureBuilder<List<_HistoryItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snapshot.error}'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() => _itemsFuture = _load()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _section == _HistorySection.watching ? Icons.play_circle_outline : Icons.check_circle_outline,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _section == _HistorySection.watching ? 'Nothing in progress yet' : 'Nothing finished yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Things you read or watch will show up here.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: item.coverImageUrl,
                              width: 52,
                              height: 72,
                              fit: BoxFit.cover,
                              memCacheWidth: 104,
                              errorWidget: (context, url, error) => Container(
                                width: 52,
                                height: 72,
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.broken_image_outlined, size: 18, color: colorScheme.outline),
                              ),
                            ),
                          ),
                          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item.isStory ? 'Story' : 'Documentary'),
                          trailing: _section == _HistorySection.watching
                              ? SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(value: item.watchProgress, strokeWidth: 3),
                                      Text('${(item.watchProgress * 100).round()}%', style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                )
                              : const Icon(Icons.check_circle, color: Colors.green),
                          onTap: () => _openItem(item),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
