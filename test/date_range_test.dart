import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/date_range.dart';

void main() {
  test('all bucket returns no bounds', () {
    final range = computeDateRange('all');
    expect(range.from, isNull);
    expect(range.to, isNull);
  });

  test('today bucket spans exactly today', () {
    final range = computeDateRange('today');
    final now = DateTime.now();
    final expectedFrom = DateTime(now.year, now.month, now.day);
    expect(range.from, expectedFrom);
    expect(range.to, expectedFrom.add(const Duration(days: 1)));
  });

  test('yesterday bucket is the day before today, up to today', () {
    final range = computeDateRange('yesterday');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(range.from, today.subtract(const Duration(days: 1)));
    expect(range.to, today);
  });

  test('thisWeek has a lower bound and no upper bound', () {
    final range = computeDateRange('thisWeek');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(range.from, today.subtract(const Duration(days: 6)));
    expect(range.to, isNull);
  });

  test('unknown bucket falls back to no bounds', () {
    final range = computeDateRange('garbage');
    expect(range.from, isNull);
    expect(range.to, isNull);
  });
}
