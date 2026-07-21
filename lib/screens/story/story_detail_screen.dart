import 'package:flutter/material.dart';
import 'package:my_app/models/story_interaction_model.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/services/story_service.dart';

/// Story detail screen -- opens when a card is tapped anywhere in the
/// app (dashboard sections/grid, trending list). Three things happen
/// automatically here, no admin/DB work involved:
///
///   1. A view is registered once per user (backend dedupes it).
///   2. Like/rating are live, tap-to-toggle / tap-a-star.
///   3. Progress is a manual slider (there's no audio/video file field
///      on Story yet, so there's nothing to auto-track playback
///      position from) -- dragging it saves automatically on release.
///      "Start Reading" / "Mark as Finished" cover the common cases
///      without needing the slider at all.
class StoryDetailScreen extends StatefulWidget {
  final String storyId;

  const StoryDetailScreen({super.key, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final _storyService = StoryService();

  late Future<_DetailData> _dataFuture;
  double? _pendingProgress; // local slider value while dragging

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DetailData> _load() async {
    final story = await _storyService.fetchStoryById(widget.storyId);
    final interactions = await _storyService.fetchInteractions(widget.storyId);
    // Fire-and-forget-ish: registers the view, but we still await it so
    // the viewCount shown on screen is accurate the first time you open it.
    final viewCount = await _storyService.registerView(widget.storyId);
    return _DetailData(story: story, interactions: interactions, liveViewCount: viewCount);
  }

  Future<void> _toggleLike(_DetailData data) async {
    try {
      final result = await _storyService.toggleLike(widget.storyId);
      setState(() {
        _dataFuture = Future.value(_DetailData(
          story: data.story,
          interactions: data.interactions.copyWith(isLiked: result.liked),
          liveViewCount: data.liveViewCount,
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
        _dataFuture = Future.value(_DetailData(
          story: data.story,
          interactions: data.interactions.copyWith(myRating: stars),
          liveViewCount: data.liveViewCount,
          liveLikeCount: data.liveLikeCount,
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
      await _storyService.updateProgress(widget.storyId, progress);
      setState(() {
        _pendingProgress = null;
        _dataFuture = Future.value(_DetailData(
          story: data.story,
          interactions: data.interactions.copyWith(progress: progress, completed: progress >= 0.98),
          liveViewCount: data.liveViewCount,
          liveLikeCount: data.liveLikeCount,
          liveRating: data.liveRating,
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
          final story = data.story;
          final interactions = data.interactions;
          final colorScheme = Theme.of(context).colorScheme;
          final displayedProgress = _pendingProgress ?? interactions.progress;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
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
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Like + rate row
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

                    // Progress
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
                            onPressed: displayedProgress > 0
                                ? null
                                : () => _saveProgress(data, 0.05),
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
                  ]),
                ),
              ),
            ],
          );
        },
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

  const _DetailData({
    required this.story,
    required this.interactions,
    required this.liveViewCount,
    this.liveLikeCount,
    this.liveRating,
  });
}
