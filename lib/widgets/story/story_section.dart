import 'package:flutter/material.dart';
import 'package:my_app/models/story_model.dart';
import 'story_card.dart';

/// One horizontal-scrolling row of stories with a title + "See all".
/// Reused for every section (Trending, Recently Added, Top Rated, etc.)
/// -- only the list of stories and the stat shown per card change.
class StorySection extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final List<StoryModel> stories;

  /// Given a story, return the small stat text to show under its title
  /// (e.g. "1.2M views" for Most Viewed, "4.7 ★" for Top Rated).
  final String Function(StoryModel story)? statLabelBuilder;
  final IconData? statIcon;

  final ValueChanged<StoryModel>? onStoryTap;
  final VoidCallback? onSeeAll;

  const StorySection({
    super.key,
    required this.title,
    this.titleIcon,
    required this.stories,
    this.statLabelBuilder,
    this.statIcon,
    this.onStoryTap,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 254,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final story = stories[index];
              return StoryCard(
                story: story,
                statLabel: statLabelBuilder?.call(story),
                statIcon: statIcon,
                onTap: () => onStoryTap?.call(story),
              );
            },
          ),
        ),
      ],
    );
  }
}
