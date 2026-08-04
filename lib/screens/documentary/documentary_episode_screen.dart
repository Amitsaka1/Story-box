import 'package:flutter/material.dart';
import 'package:my_app/models/comment_model.dart';
import 'package:my_app/models/story_content_model.dart';
import 'package:my_app/services/documentary_service.dart';

/// Full-screen single-episode reader for Documentary -- exact mirror of
/// StoryEpisodeScreen (pages, zero gap, pinch-to-zoom, comments in a
/// bottom sheet).
class DocumentaryEpisodeScreen extends StatefulWidget {
  final String documentaryId;
  final int chapterNo;
  final List<StoryPage> pages;
  final int totalChapters;
  final bool isLiked;

  const DocumentaryEpisodeScreen({
    super.key,
    required this.documentaryId,
    required this.chapterNo,
    required this.pages,
    required this.totalChapters,
    required this.isLiked,
  });

  @override
  State<DocumentaryEpisodeScreen> createState() => _DocumentaryEpisodeScreenState();
}

class _DocumentaryEpisodeScreenState extends State<DocumentaryEpisodeScreen> {
  final _documentaryService = DocumentaryService();
  final _transformationController = TransformationController();

  late bool _isLiked = widget.isLiked;

  @override
  void initState() {
    super.initState();
    _trackProgress();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _trackProgress() async {
    final progress = widget.totalChapters > 0 ? widget.chapterNo / widget.totalChapters : 0.0;
    try {
      await _documentaryService.updateProgress(widget.documentaryId, progress, lastChapterNo: widget.chapterNo);
    } catch (_) {
      // Silent, same reasoning as Story.
    }
  }

  Future<void> _toggleLike() async {
    try {
      final result = await _documentaryService.toggleLike(widget.documentaryId);
      if (!mounted) return;
      setState(() => _isLiked = result.liked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _CommentsSheet(
          documentaryId: widget.documentaryId,
          documentaryService: _documentaryService,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.pages]..sort((a, b) => a.pageNo.compareTo(b.pageNo));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Episode ${widget.chapterNo}'),
        actions: [
          IconButton(
            onPressed: _toggleLike,
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
          ),
          IconButton(
            onPressed: _openCommentsSheet,
            icon: const Icon(Icons.mode_comment_outlined),
          ),
        ],
      ),
      body: sorted.isEmpty
          ? const Center(child: Text('Is episode ke pages abhi load nahi hue.', style: TextStyle(color: Colors.white70)))
          : InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1,
              maxScale: 4,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final page = sorted[index];
                  return Image.network(
                    page.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return AspectRatio(
                        aspectRatio: 0.7,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => const AspectRatio(
                      aspectRatio: 0.7,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Comment thread, in a bottom sheet so the reader itself stays
/// fullscreen -- exact mirror of Story's _CommentsSheet.
class _CommentsSheet extends StatefulWidget {
  final String documentaryId;
  final DocumentaryService documentaryService;
  final ScrollController scrollController;

  const _CommentsSheet({required this.documentaryId, required this.documentaryService, required this.scrollController});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();

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
    _loadCommentsInitial();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_commentsHasMore || _commentsLoadingMore || _commentsInitialLoading) return;
    final threshold = widget.scrollController.position.maxScrollExtent - 400;
    if (widget.scrollController.position.pixels >= threshold) {
      _loadCommentsMore();
    }
  }

  Future<void> _loadCommentsInitial() async {
    setState(() => _commentsInitialLoading = true);
    try {
      final result = await widget.documentaryService.fetchComments(widget.documentaryId, page: 1);
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
      final result = await widget.documentaryService.fetchComments(widget.documentaryId, page: nextPage);
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
      final comment = await widget.documentaryService.postComment(widget.documentaryId, text);
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
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
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
    );
  }
}
