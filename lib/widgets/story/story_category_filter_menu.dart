import 'package:flutter/material.dart';

/// Sentinel value meaning "no category filter" -- shown as "All" in
/// the menu, but doesn't get its own chip like Documentary's sort did.
const String kAllCategories = 'All';

/// A compact icon-only button that opens a dropdown menu to pick a
/// story category (Drama, Thriller, ...) or "All". Shows a small green
/// dot when a specific category is active, mirroring
/// DocumentarySortMenu's pattern. Sits to the left of the time filter
/// chips -- pure UI, parent owns the selected value.
class StoryCategoryFilterMenu extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  const StoryCategoryFilterMenu({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFilterActive = selected != kAllCategories;
    final options = [kAllCategories, ...categories];

    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: (value) {
        // Tapping the already-active category again clears the filter
        // back to "All" -- same reset pattern as the Documentary sort menu.
        onChanged(value == selected ? kAllCategories : value);
      },
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => options.map((option) {
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              Text(option),
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
            Icon(Icons.category_outlined, size: 20, color: colorScheme.onSurfaceVariant),
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
