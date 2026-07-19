import 'package:flutter/material.dart';
import 'package:my_app/models/story_model.dart';

/// A single story's poster card -- used inside every horizontal
/// section (Trending, Top Rated, etc). Pure UI, no logic: parent
/// decides what list of stories to show and passes one story in.
class StoryCard extends StatelessWidget {
  final StoryModel story;
  final VoidCallback? onTap;

  /// Optional small stat shown under the title, e.g. "1.2M views"
  /// or "4.7 ★" -- lets each section highlight a different metric
  /// (views for "Most Viewed", rating for "Top Rated", etc.)
  final String? statLabel;
  final IconData? statIcon;

  const StoryCard({
    super.key,
    required this.story,
    this.onTap,
    this.statLabel,
    this.statIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      story.coverImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_outlined, color: colorScheme.outline),
                      ),
                    ),
                    // subtle bottom gradient so any future overlay text stays readable
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              story.rating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              story.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (statLabel != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (statIcon != null) ...[
                    Icon(statIcon, size: 13, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      statLabel!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
