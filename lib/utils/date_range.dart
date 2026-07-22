/// Computes [from, to) date boundaries for a time-filter bucket name.
/// Matches StoryTimeFilter/DocumentaryTimeFilter enum value names
/// exactly (all, today, yesterday, thisWeek, thisMonth, thisYear) --
/// call this with `_timeFilter.name`.
///
/// Same logic the tabs used to run client-side, just moved here so
/// both Story and Documentary tabs share one implementation and the
/// backend gets exact boundaries (device-local "now", same as before --
/// no server-timezone mismatch).
({DateTime? from, DateTime? to}) computeDateRange(String bucket) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (bucket) {
    case 'today':
      return (from: today, to: today.add(const Duration(days: 1)));
    case 'yesterday':
      final yesterday = today.subtract(const Duration(days: 1));
      return (from: yesterday, to: today);
    case 'thisWeek':
      return (from: today.subtract(const Duration(days: 6)), to: null);
    case 'thisMonth':
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
      return (from: monthStart, to: nextMonthStart);
    case 'thisYear':
      return (from: DateTime(now.year, 1, 1), to: DateTime(now.year + 1, 1, 1));
    case 'all':
    default:
      return (from: null, to: null);
  }
}
