import 'package:flutter/material.dart';

/// The ways a documentary list can be sorted. "popularity" is the
/// default (combined rating+like+comment+view score) used for "All".
/// Treated as the "no filter applied" state -- the green dot only
/// shows when the user picks something other than this.
enum DocumentarySortOption { popularity, rating, likes, comments, views }

extension DocumentarySortOptionLabel on DocumentarySortOption {
  String get label {
    switch (this) {
      case DocumentarySortOption.popularity:
        return 'Popular';
      case DocumentarySortOption.rating:
        return 'Rating';
      case DocumentarySortOption.likes:
        return 'Likes';
      case DocumentarySortOption.comments:
        return 'Comments';
      case DocumentarySortOption.views:
        return 'Views';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentarySortOption.popularity:
        return Icons.local_fire_department_outlined;
      case DocumentarySortOption.rating:
        return Icons.star_outline;
      case DocumentarySortOption.likes:
        return Icons.favorite_border;
      case DocumentarySortOption.comments:
        return Icons.mode_comment_outlined;
      case DocumentarySortOption.views:
        return Icons.visibility_outlined;
    }
  }
}

/// A compact icon-only button that opens a dropdown menu to pick how
/// the grid is sorted (Rating / Likes / Comments / Views / Popular).
/// Shows a small green dot when a non-default sort is active, instead
/// of spelling out the sort name -- pure UI, parent owns the value.
class DocumentarySortMenu extends StatelessWidget {
  final DocumentarySortOption selected;
  final ValueChanged<DocumentarySortOption> onChanged;

  const DocumentarySortMenu({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFilterActive = selected != DocumentarySortOption.popularity;

    return PopupMenuButton<DocumentarySortOption>(
      initialValue: selected,
      onSelected: onChanged,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => DocumentarySortOption.values.map((option) {
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              Icon(option.icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(option.label),
              if (option == selected) ...[
                const Spacer(),
                Icon(Icons.check, size: 18, color: colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 20, right: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(Icons.sort, size: 20, color: colorScheme.onSurfaceVariant),
            if (isFilterActive)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
