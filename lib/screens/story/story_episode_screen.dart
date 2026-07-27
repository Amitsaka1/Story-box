import 'package:flutter/material.dart';
import 'package:my_app/models/comment_model.dart';
import 'package:my_app/services/story_service.dart';

/// Full-screen single-episode reader -- chapter text, Like/Dislike, and
/// the (story-wide, not per-episode) comment thread, all merged onto
/// one screen.
class StoryEpisodeScreen extends StatefulWidget {
  final String storyId;
  final int chapterNo;
  final String chapterText;
  final int totalChapters;
  final bool isLiked;

  const StoryEpisodeScreen({
    super.key,
    required this.storyId,
    required this.chapterNo,
    required this.chapterText,
    required this.totalChapters,
    required this.isLiked,
  });

  @override
  State<StoryEpisodeScreen> createState() => _StoryEpisodeScreenState();
}

class _StoryEpisodeScreenState extends State<StoryEpisodeScreen> {
  final _storyService = StoryService();
  final _scrollController = ScrollController();
  final _commentController = TextEditingController();

  late bool _isLiked = widget.isLiked;
  // Cosmetic only, confirmed no backend effect.
  bool _dislikedLocally = false;

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
    _trackProgress();
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

  Future<void> _trackProgress() async {
    final progress = widget.totalChapters > 0 ? widget.chapterNo / widget.totalChapters : 0.0;
    try {
      await _storyService.updateProgress(widget.storyId, progress, lastChapterNo: widget.chapterNo);
    } catch (_) {
      // Silent -- opening the episode still works even if this ping
      // fails; it'll just retry next time an episode is opened.
    }
  }

  Future<void> _toggleLike() async {
    try {
      final result = await _storyService.toggleLike(widget.storyId);
      if (!mounted) return;
      setState(() => _isLiked = result.liked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Episode ${widget.chapterNo}')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.chapterText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _toggleLike,
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                label: Text(_isLiked ? 'Liked' : 'Like'),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => setState(() => _dislikedLocally = !_dislikedLocally),
                icon: Icon(_dislikedLocally ? Icons.thumb_down : Icons.thumb_down_outlined),
                color: _dislikedLocally ? colorScheme.error : null,
              ),
            ],
          ),
          const SizedBox(height: 32),
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
}
