import 'package:flutter/material.dart';
import 'package:my_app/models/story_content_model.dart';
import 'package:my_app/models/documentary_interaction_model.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/services/documentary_service.dart';

class DocumentaryDetailScreen extends StatefulWidget {
  final String documentaryId;

  const DocumentaryDetailScreen({super.key, required this.documentaryId});

  @override
  State<DocumentaryDetailScreen> createState() => _DocumentaryDetailScreenState();
}

class _DocumentaryDetailScreenState extends State<DocumentaryDetailScreen> {
  final _documentaryService = DocumentaryService();

  late Future<_DetailData> _dataFuture;
  double? _pendingProgress;

  int _selectedChapterNo = 1;
  bool _showAllEpisodesPanel = false;
  bool _dislikedLocally = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DetailData> _load() async {
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

    return _DetailData(
      documentary: documentary,
      interactions: interactions,
      liveViewCount: viewCount,
      content: content,
      contentError: contentError,
    );
  }

  Future<void> _toggleLike(_DetailData data) async {
    try {
      final result = await _documentaryService.toggleLike(widget.documentaryId);
      setState(() {
        _dataFuture = Future.value(data.copyWith(
          interactions: data.interactions.copyWith(isLiked: result.liked),
          liveLikeCount: result.likeCount,
        ));
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
        _dataFuture = Future.value(data.copyWith(
          interactions: data.interactions.copyWith(myRating: stars),
          liveRating: avg,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _saveProgress(_DetailData data, double progress) async {
    try {
      await _documentaryService.updateProgress(widget.documentaryId, progress);
      setState(() {
        _pendingProgress = null;
        _dataFuture = Future.value(data.copyWith(
          interactions: data.interactions.copyWith(progress: progress, completed: progress >= 0.98),
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingProgress = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DetailData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _dataFuture = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final documentary = data.documentary;
          final interactions = data.interactions;
          final colorScheme = Theme.of(context).colorScheme;
          final screenWidth = MediaQuery.of(context).size.width;
          final bannerHeight = screenWidth * 1.5;
          final displayedProgress = _pendingProgress ?? interactions.progress;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: bannerHeight,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        documentary.coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
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
                        Icon(Icons.star, size: 16, color: Colors.amber),
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
                            icon: Icon(
                              filled ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your progress', style: Theme.of(context).textTheme.titleSmall),
                        if (interactions.completed)
                          Chip(
                            label: const Text('Finished'),
                            avatar: const Icon(Icons.check_circle, size: 16),
                            visualDensity: VisualDensity.compact,
                          )
                        else
                          Text('${(displayedProgress * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: displayedProgress,
                      onChanged: (v) => setState(() => _pendingProgress = v),
                      onChangeEnd: (v) => _saveProgress(data, v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: displayedProgress > 0 ? null : () => _saveProgress(data, 0.05),
                            child: const Text('Start'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: interactions.completed ? null : () => _saveProgress(data, 1.0),
                            child: const Text('Mark as Finished'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Documentary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    if (data.content != null)
                      _buildEpisodeReader(context, data, colorScheme)
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

  Widget _buildEpisodeReader(BuildContext context, _DetailData data, ColorScheme colorScheme) {
    final chapters = data.content!.chapters;
    if (chapters.isEmpty) {
      return Text('Is documentary me abhi koi episode nahi hai.', style: TextStyle(color: colorScheme.onSurfaceVariant));
    }

    final sorted = [...chapters]..sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    final visibleCount = sorted.length > 10 ? 10 : sorted.length;
    final hasMore = sorted.length > 10;
    final selected = sorted.firstWhere(
      (c) => c.chapterNo == _selectedChapterNo,
      orElse: () => sorted.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final chapter in sorted.take(visibleCount)) ...[
                _EpisodeNumberButton(
                  number: chapter.chapterNo,
                  selected: chapter.chapterNo == _selectedChapterNo,
                  onTap: () => setState(() => _selectedChapterNo = chapter.chapterNo),
                ),
                const SizedBox(width: 8),
              ],
              if (hasMore)
                OutlinedButton(
                  onPressed: () => setState(() => _showAllEpisodesPanel = true),
                  child: const Text('More'),
                ),
            ],
          ),
        ),
        if (_showAllEpisodesPanel) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('All Episodes', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _showAllEpisodesPanel = false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final chapter = sorted[index];
                    return _EpisodeNumberButton(
                      number: chapter.chapterNo,
                      selected: chapter.chapterNo == _selectedChapterNo,
                      onTap: () => setState(() => _selectedChapterNo = chapter.chapterNo),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Chapter ${selected.chapterNo}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          selected.text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _toggleLike(data),
              icon: Icon(data.interactions.isLiked ? Icons.favorite : Icons.favorite_border),
              label: Text(data.interactions.isLiked ? 'Liked' : 'Like'),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => setState(() => _dislikedLocally = !_dislikedLocally),
              icon: Icon(_dislikedLocally ? Icons.thumb_down : Icons.thumb_down_outlined),
              color: _dislikedLocally ? Theme.of(context).colorScheme.error : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _EpisodeNumberButton extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _EpisodeNumberButton({required this.number, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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
}
