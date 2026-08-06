import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_app/core/local_cache.dart';
import 'package:my_app/models/story_content_model.dart';
import 'package:my_app/models/documentary_interaction_model.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/screens/documentary/documentary_episode_screen.dart';
import 'package:my_app/services/documentary_service.dart';

class DocumentaryDetailScreen extends StatefulWidget {
  final String documentaryId;

  const DocumentaryDetailScreen({super.key, required this.documentaryId});

  @override
  State<DocumentaryDetailScreen> createState() => _DocumentaryDetailScreenState();
}

class _DocumentaryDetailScreenState extends State<DocumentaryDetailScreen> {
  final _documentaryService = DocumentaryService();

  String get _cacheKey => 'documentary_detail_${widget.documentaryId}';

  _DetailData? _data;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(useCache: true);
  }

  Future<void> _load({bool useCache = false}) async {
    if (useCache) {
      final cached = LocalCache.read(_cacheKey);
      if (cached != null) {
        try {
          setState(() {
            _data = _DetailData.fromCacheJson(cached as Map<String, dynamic>);
            _loading = false;
          });
        } catch (_) {
          // Old/corrupt cache shape -- ignore, fresh fetch below still runs.
        }
      }
    }

    setState(() {
      _loading = _data == null;
      _error = null;
    });

    try {
      final documentary = await _documentaryService.fetchDocumentaryById(widget.documentaryId);
      final interactions = await _documentaryService.fetchInteractions(widget.documentaryId);
      final viewCount = await _documentaryService.registerView(widget.documentaryId);

      StoryContentModel? content;
      String? contentError;
      if (documentary.contentUrl.isNotEmpty) {
        try {
          content = await _documentaryService.fetchDocumentaryContent(documentary.contentUrl);
        } catch (e) {
          contentError = '$e';
        }
      } else {
        contentError = 'Is documentary ke liye abhi text add nahi hua hai.';
      }

      final fresh = _DetailData(
        documentary: documentary,
        interactions: interactions,
        liveViewCount: viewCount,
        content: content,
        contentError: contentError,
      );

      if (!mounted) return;
      setState(() {
        _data = fresh;
        _loading = false;
      });
      LocalCache.save(_cacheKey, fresh.toJson());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_data == null) _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike(_DetailData data) async {
    try {
      final result = await _documentaryService.toggleLike(widget.documentaryId);
      setState(() {
        _data = data.copyWith(
          interactions: data.interactions.copyWith(isLiked: result.liked),
          liveLikeCount: result.likeCount,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rate(_DetailData data, int stars) async {
    try {
      final avg = await _documentaryService.rateDocumentary(widget.documentaryId, stars);
      setState(() {
        _data = data.copyWith(
          interactions: data.interactions.copyWith(myRating: stars),
          liveRating: avg,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openEpisode(_DetailData data, StoryChapter chapter, int totalChapters) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DocumentaryEpisodeScreen(
            documentaryId: widget.documentaryId,
            chapterNo: chapter.chapterNo,
            pages: chapter.pages,
            totalChapters: totalChapters,
            isLiked: data.interactions.isLiked,
          ),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_error', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = _data!;
          final documentary = data.documentary;
          final interactions = data.interactions;
          final colorScheme = Theme.of(context).colorScheme;
          final screenWidth = MediaQuery.of(context).size.width;
          final bannerHeight = screenWidth * 1.5;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: bannerHeight,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: documentary.coverImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined, size: 48, color: colorScheme.outline),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      documentary.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Chip(label: Text(documentary.category), visualDensity: VisualDensity.compact),
                        const SizedBox(width: 10),
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text((data.liveRating ?? documentary.rating).toStringAsFixed(1)),
                        const SizedBox(width: 12),
                        Icon(Icons.visibility_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(DocumentaryModel.formatCount(data.liveViewCount)),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(DocumentaryModel.formatCount(data.liveLikeCount ?? documentary.likeCount)),
                        if (interactions.completed) ...[
                          const SizedBox(width: 12),
                          const Chip(
                            label: Text('Finished'),
                            avatar: Icon(Icons.check_circle, size: 14),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _toggleLike(data),
                          icon: Icon(interactions.isLiked ? Icons.favorite : Icons.favorite_border),
                          label: Text(interactions.isLiked ? 'Liked' : 'Like'),
                        ),
                        const SizedBox(width: 16),
                        Text('Rate:', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(width: 4),
                        ...List.generate(5, (i) {
                          final starIndex = i + 1;
                          final filled = (interactions.myRating ?? 0) >= starIndex;
                          return IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _rate(data, starIndex),
                            icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Documentary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    if (data.content != null)
                      _buildEpisodeGrid(context, data, data.content!.chapters, interactions.lastChapterNo)
                    else
                      Text(
                        data.contentError ?? 'Text load nahi ho paya.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodeGrid(BuildContext context, _DetailData data, List<StoryChapter> chapters, int lastChapterNo) {
    final colorScheme = Theme.of(context).colorScheme;
    if (chapters.isEmpty) {
      return Text('Is documentary me abhi koi episode nahi hai.', style: TextStyle(color: colorScheme.onSurfaceVariant));
    }
    final sorted = [...chapters]..sort((a, b) => a.chapterNo.compareTo(b.chapterNo));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final chapter = sorted[index];
        return _EpisodeButton(
          number: chapter.chapterNo,
          isLastOpened: chapter.chapterNo == lastChapterNo,
          onTap: () => _openEpisode(data, chapter, sorted.length),
        );
      },
    );
  }
}

class _EpisodeButton extends StatelessWidget {
  static const _skyBlue = Color(0xFF29B6F6);

  final int number;
  final bool isLastOpened;
  final VoidCallback onTap;

  const _EpisodeButton({required this.number, required this.isLastOpened, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isLastOpened) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(backgroundColor: _skyBlue, padding: const EdgeInsets.symmetric(horizontal: 4)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Episode $number', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _skyBlue,
        side: const BorderSide(color: _skyBlue),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('Episode $number', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _DetailData {
  final DocumentaryModel documentary;
  final DocumentaryInteractionModel interactions;
  final int liveViewCount;
  final int? liveLikeCount;
  final double? liveRating;
  final StoryContentModel? content;
  final String? contentError;

  const _DetailData({
    required this.documentary,
    required this.interactions,
    required this.liveViewCount,
    this.liveLikeCount,
    this.liveRating,
    this.content,
    this.contentError,
  });

  _DetailData copyWith({
    DocumentaryInteractionModel? interactions,
    int? liveLikeCount,
    double? liveRating,
  }) {
    return _DetailData(
      documentary: documentary,
      interactions: interactions ?? this.interactions,
      liveViewCount: liveViewCount,
      liveLikeCount: liveLikeCount ?? this.liveLikeCount,
      liveRating: liveRating ?? this.liveRating,
      content: content,
      contentError: contentError,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentary': documentary.toJson(),
        'interactions': interactions.toJson(),
        'liveViewCount': liveViewCount,
        'liveLikeCount': liveLikeCount,
        'liveRating': liveRating,
        'content': content?.toJson(),
        'contentError': contentError,
      };

  factory _DetailData.fromCacheJson(Map<String, dynamic> json) => _DetailData(
        documentary: DocumentaryModel.fromJson(json['documentary'] as Map<String, dynamic>),
        interactions: DocumentaryInteractionModel.fromJson(json['interactions'] as Map<String, dynamic>),
        liveViewCount: json['liveViewCount'] as int,
        liveLikeCount: json['liveLikeCount'] as int?,
        liveRating: (json['liveRating'] as num?)?.toDouble(),
        content: json['content'] != null ? StoryContentModel.fromJson(json['content'] as Map<String, dynamic>) : null,
        contentError: json['contentError'] as String?,
      );
}
