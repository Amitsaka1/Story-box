import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
/// The set of time buckets a documentary can fall into. Kept as an
/// enum (not free strings) so the filtering logic in documentary_tab.dart
/// can't typo a label and silently show nothing.
enum DocumentaryTimeFilter { all, today, yesterday, thisWeek, thisMonth, thisYear }

extension DocumentaryTimeFilterLabel on DocumentaryTimeFilter {
  String get label {
    switch (this) {
      case DocumentaryTimeFilter.all:
        return 'story.time_all'.tr();
      case DocumentaryTimeFilter.today:
        return 'story.time_today'.tr();
      case DocumentaryTimeFilter.yesterday:
        return 'story.time_yesterday'.tr();
      case DocumentaryTimeFilter.thisWeek:
        return 'story.time_this_week'.tr();
      case DocumentaryTimeFilter.thisMonth:
        return 'story.time_this_month'.tr();
      case DocumentaryTimeFilter.thisYear:
        return 'story.time_this_year'.tr();
    }
  }
}

/// Horizontal-scrolling time-range chips (All, Today, Yesterday, ...).
/// Pure UI -- parent owns which filter is selected and passes it in.
class DocumentaryTimeFilterBar extends StatelessWidget {
  final DocumentaryTimeFilter selected;
  final ValueChanged<DocumentaryTimeFilter> onSelected;

  const DocumentaryTimeFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: DocumentaryTimeFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = DocumentaryTimeFilter.values[index];
          final isSelected = filter == selected;

          return ChoiceChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) => onSelected(filter),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          );
        },
      ),
    );
  }
}
