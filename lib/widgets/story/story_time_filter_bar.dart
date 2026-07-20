import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// The set of time buckets a story can fall into -- same pattern as
/// DocumentaryTimeFilter, kept separate so each tab's filter logic
/// stays independent.
enum StoryTimeFilter { all, today, yesterday, thisWeek, thisMonth, thisYear }

extension StoryTimeFilterLabel on StoryTimeFilter {
  String get label {
    switch (this) {
      case StoryTimeFilter.all:
        return 'story.time_all'.tr();
      case StoryTimeFilter.today:
        return 'story.time_today'.tr();
      case StoryTimeFilter.yesterday:
        return 'story.time_yesterday'.tr();
      case StoryTimeFilter.thisWeek:
        return 'story.time_this_week'.tr();
      case StoryTimeFilter.thisMonth:
        return 'story.time_this_month'.tr();
      case StoryTimeFilter.thisYear:
        return 'story.time_this_year'.tr();
    }
  }
}

/// Horizontal-scrolling time-range chips (All, Today, Yesterday, ...).
/// Pure UI -- parent owns which filter is selected and passes it in.
class StoryTimeFilterBar extends StatelessWidget {
  final StoryTimeFilter selected;
  final ValueChanged<StoryTimeFilter> onSelected;

  const StoryTimeFilterBar({
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
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemCount: StoryTimeFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = StoryTimeFilter.values[index];
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
