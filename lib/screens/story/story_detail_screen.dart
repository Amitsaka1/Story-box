import 'package:flutter/material.dart';
import 'package:my_app/models/comment_model.dart';
import 'package:my_app/models/story_content_model.dart';
export 'package:my_app/models/story_content_model.dart' show StoryChapter;
import 'package:my_app/models/story_interaction_model.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/services/story_service.dart';

class StoryDetailScreen extends StatefulWidget {
  final String storyId;

  const StoryDetailScreen({super.key, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final _storyService = StoryService();

  late Future<_DetailData> _dataFuture;

  // Episode selector state -- which episode's text is currently shown,
  // and whether the "All Episodes" panel is expanded. The panel stays
  // open across episode picks until manually closed (per product spec).
  int _selectedChapterNo = 1;
  bool _showAllEpisodesPanel = false;

  // Dislike is purely cosmetic (confirmed: no backend effect) -- one
  // local toggle for the whole screen, shown at the end of whichever
  // episode is currently open.
  bool _dislikedLocally = false;

  // Comments -- story-wide (not per-episode), infinite scroll.
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final List<CommentModel> _comments = [];
  int _commentsPage = 1;
  bool _commentsHasMore = true;
  bool _commentsInitialLoading = true;
  bool _commentsLoadingMore = false;
  int _commentsTotalCount = 0;
  bool _postingComment = false;
  
  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    // Resume into whichever episode the reader last had open.
    _dataFuture.then((data) {
      if (!mounted) return;
      setState(() => _selectedChapterNo = data.interactions.lastChapterNo);
    });
    _loadCommentsInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_commentsHasMore || _commentsLoadingMore || _commentsInitialLoading) return;
    final threshold = _scrollController.position.maxScrollExtent - 400;
    if (_scrollController.position.pixels >= threshold) {
      _loadCommentsMore();
    }
  }

  Future<void> _loadCommentsInitial() async {
    setState(() => _commentsInitialLoading = true);
    try {
      final result = await _storyService.fetchComments(widget.storyId, page: 1);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(result.data);
        _commentsHasMore = result.hasMore;
        _commentsTotalCount = result.totalCount;
        _commentsPage = 1;
        _commentsInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentsInitialLoading = false);
    }
  }

  Future<void> _loadCommentsMore() async {
    setState(() => _commentsLoadingMore = true);
    try {
      final nextPage = _commentsPage + 1;
      final result = await _storyService.fetchComments(widget.storyId, page: nextPage);
      if (!mounted) return;
      setState(() {
        _comments.addAll(result.data);
        _commentsHasMore = result.hasMore;
        _commentsPage = nextPage;
        _commentsLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentsLoadingMore = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _postingComment) return;
    setState(() => _postingComment = true);
    try {
      final comment = await _storyService.postComment(widget.storyId, text);
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _commentsTotalCount += 1;
        _commentController.clear();
        _postingComment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _postingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _timeAgoShort(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Widget _buildCommentsSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Comments ($_commentsTotalCount)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Write a comment...', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _postingComment ? null : _submitComment,
                icon: _postingComment
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_commentsInitialLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_comments.isEmpty)
            Text('No comments yet -- be the first!', style: TextStyle(color: colorScheme.onSurfaceVariant))
          else ...[
            for (final comment in _comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(comment.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgoShort(comment.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment.text),
                  ],
                ),
              ),
            if (_commentsLoadingMore)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          ],
        ],
      ),
    );
  }

  Future<_DetailData> _load() async {
    final story = await _storyService.fetchStoryById(widget.storyId);
    final interactions = await _storyService.fetchInteractions(widget.storyId);
    final viewCount = await _storyService.registerView(widget.storyId);

    // Content fetch alag try/catch me -- agar CDN file missing/purani
    // story me contentUrl na ho, poora screen crash nahi hona chahiye,
    // bas "text load nahi ho paya" dikhna chahiye.
    StoryContentModel? content;
    String? contentError;
    if (story.contentUrl.isNotEmpty) {
      try {
        content = await _storyService.fetchStoryContent(story.contentUrl);
      } catch (e) {
        contentError = '$e';
      }
    } else {
      contentError = 'Is story ke liye abhi text add nahi hua hai.';
    }

    return _DetailData(
      story: story,
      interactions: interactions,
      liveViewCount: viewCount,
      content: content,
      contentError: contentError,
    );
  }

  Future<void> _toggleLike(_DetailData data) async {
    try {
      final result = await _storyService.toggleLike(widget.storyId);
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
      final avg = await _storyService.rateStory(widget.storyId, stars);
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

  // Called automatically whenever the reader opens an episode (top row
  // or the "All Episodes" panel) -- no manual slider/buttons anymore.
  // progress = chapterNo/totalChapters; "completed" comes back from the
  // backend, which combines "last episode reached" with the story's
  // own ongoing/completed status.
  Future<void> _trackProgress(_DetailData data, int chapterNo, int totalChapters) async {
    final progress = totalChapters > 0 ? chapterNo / totalChapters : 0.0;
    try {
      final completed = await _storyService.updateProgress(widget.storyId, progress, lastChapterNo: chapterNo);
      if (!mounted) return;
      setState(() {
        _dataFuture = Future.value(data.copyWith(
          interactions: data.interactions.copyWith(progress: progress, completed: completed, lastChapterNo: chapterNo),
        ));
      });
    } catch (_) {
      // Silent -- a failed progress save shouldn't interrupt reading
      // with an error popup. It'll just try again next episode switch.
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
          final story = data.story;
          final interactions = data.interactions;
          final colorScheme = Theme.of(context).colorScheme;
          final screenWidth = MediaQuery.of(context).size.width;
          final bannerHeight = screenWidth * 1.5;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: bannerHeight,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        story.coverImageUrl,
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
                      story.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Chip(label: Text(story.category), visualDensity: VisualDensity.compact),
                        const SizedBox(width: 10),
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text((data.liveRating ?? story.rating).toStringAsFixed(1)),
                        const SizedBox(width: 12),
                        Icon(Icons.visibility_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(StoryModel.formatCount(data.liveViewCount)),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(StoryModel.formatCount(data.liveLikeCount ?? story.likeCount)),
                        if (interactions.completed) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: const Text('Finished'),
                            avatar: const Icon(Icons.check_circle, size: 14),
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
                            icon: Icon(
                              filled ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ],
                    ),
                    // ---------------- Story text (yahi neeche padhne wala part) ----------------
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Story', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    if (data.content != null)
                      _buildEpisodeReader(context, data, colorScheme)
                    else
                      Text(
                        data.contentError ?? 'Text load nahi ho paya.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    _buildCommentsSection(context, colorScheme),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Builds the episode number-selector row + "All Episodes" expandable
  // panel + the currently-selected episode's text + Like/Dislike row.
  Widget _buildEpisodeReader(BuildContext context, _DetailData data, ColorScheme colorScheme) {
    final chapters = data.content!.chapters;
    if (chapters.isEmpty) {
      return Text('Is story me abhi koi episode nahi hai.', style: TextStyle(color: colorScheme.onSurfaceVariant));
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
                  onTap: () {
                    setState(() => _selectedChapterNo = chapter.chapterNo);
                    _trackProgress(data, chapter.chapterNo, sorted.length);
                  },
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
                      // Manual close only -- picking an episode here does
                      // NOT auto-close the panel.
                      onTap: () {
                        setState(() => _selectedChapterNo = chapter.chapterNo);
                        _trackProgress(data, chapter.chapterNo, sorted.length);
                      },
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
            // Cosmetic only -- confirmed no backend call, just a visual
            // toggle so tapping it "feels" like something happened.
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

// Small reusable numbered button -- used both in the top row and inside
// the "All Episodes" grid, so both look/behave identically.
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
  final StoryModel story;
  final StoryInteractionModel interactions;
  final int liveViewCount;
  final int? liveLikeCount;
  final double? liveRating;
  final StoryContentModel? content;
  final String? contentError;

  const _DetailData({
    required this.story,
    required this.interactions,
    required this.liveViewCount,
    this.liveLikeCount,
    this.liveRating,
    this.content,
    this.contentError,
  });

  _DetailData copyWith({
    StoryInteractionModel? interactions,
    int? liveLikeCount,
    double? liveRating,
  }) {
    return _DetailData(
      story: story,
      interactions: interactions ?? this.interactions,
      liveViewCount: liveViewCount,
      liveLikeCount: liveLikeCount ?? this.liveLikeCount,
      liveRating: liveRating ?? this.liveRating,
      content: content,
      contentError: contentError,
    );
  }
}
