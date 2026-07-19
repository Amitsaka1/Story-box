import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/models/story_model.dart';
import 'story_card.dart';

/// A horizontal story list that automatically slides forward by one
/// card every few seconds (smooth animated step, not a continuous
/// scroll), while still allowing the user to manually swipe left/right
/// whenever they want. The list is internally duplicated so the loop
/// back to the start is seamless.
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
  static const double _step = _cardWidth + _cardSpacing;
  static const Duration _interval = Duration(seconds: 3);
  static const Duration _animDuration = Duration(milliseconds: 550);

  final ScrollController _controller = ScrollController();
  Timer? _timer;
  late final double _singleSetWidth;

  @override
  void initState() {
    super.initState();
    _singleSetWidth = widget.stories.length * _step;
    if (widget.stories.length >= 2) {
      _timer = Timer.periodic(_interval, (_) => _advance());
    }
  }

  Future<void> _advance() async {
    if (!_controller.hasClients) return;

    final target = _controller.offset + _step;
    await _controller.animateTo(
      target,
      duration: _animDuration,
      curve: Curves.easeInOut,
    );

    // Once we've slid past one full lap, snap back silently to the
    // equivalent position at the start -- because the list below is
    // duplicated, this jump is visually seamless.
    if (_controller.hasClients && _controller.offset >= _singleSetWidth) {
      _controller.jumpTo(_controller.offset - _singleSetWidth);
    }
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
      // Manual swiping stays enabled -- the timer above just nudges
      // the same controller every few seconds in between user drags.
      physics: const BouncingScrollPhysics(),
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
