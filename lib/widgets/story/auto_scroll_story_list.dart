import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/models/story_model.dart';
import 'story_card.dart';

/// A horizontal story list that scrolls itself continuously to the
/// left, looping forever -- used for "always moving" sections like
/// Trending / Recently Added. The list is internally duplicated so
/// that once it scrolls past the end, it snaps back seamlessly to
/// the start (looks infinite to the eye).
class AutoScrollStoryList extends StatefulWidget {
  final List<StoryModel> stories;
  final IconData? statIcon;
  final String Function(StoryModel story)? statLabelBuilder;
  final ValueChanged<StoryModel>? onStoryTap;

  const AutoScrollStoryList({
    super.key,
    required this.stories,
    this.statIcon,
    this.statLabelBuilder,
    this.onStoryTap,
  });

  @override
  State<AutoScrollStoryList> createState() => _AutoScrollStoryListState();
}

class _AutoScrollStoryListState extends State<AutoScrollStoryList> {
  static const double _cardWidth = 130;
  static const double _cardSpacing = 14;
  static const double _pixelsPerTick = 0.6; // scroll speed -- tweak to taste
  static const Duration _tickDuration = Duration(milliseconds: 16);

  final ScrollController _controller = ScrollController();
  Timer? _timer;
  late final double _singleSetWidth;

  @override
  void initState() {
    super.initState();
    _singleSetWidth = widget.stories.length * (_cardWidth + _cardSpacing);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    if (widget.stories.length < 2) return; // nothing meaningful to loop
    _timer = Timer.periodic(_tickDuration, (_) {
      if (!_controller.hasClients) return;
      final next = _controller.offset + _pixelsPerTick;
      if (next >= _singleSetWidth) {
        // Past one full lap -- jump back by exactly one set's width.
        // Because the list is duplicated below, this is seamless.
        _controller.jumpTo(next - _singleSetWidth);
      } else {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loopCount = widget.stories.length < 2 ? 1 : 2;

    return ListView.separated(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      // Auto-scroll drives this list, so manual swiping is disabled --
      // taps on cards still work fine.
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: widget.stories.length * loopCount,
      separatorBuilder: (_, __) => const SizedBox(width: _cardSpacing),
      itemBuilder: (context, index) {
        final story = widget.stories[index % widget.stories.length];
        return StoryCard(
          story: story,
          statLabel: widget.statLabelBuilder?.call(story),
          statIcon: widget.statIcon,
          onTap: () => widget.onStoryTap?.call(story),
        );
      },
    );
  }
}
