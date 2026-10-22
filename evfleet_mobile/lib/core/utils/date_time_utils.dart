import 'package:intl/intl.dart';

/// Date/time helpers shared by the booking flow, history and cards.
abstract final class DateTimeUtils {
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime addMinutes(DateTime value, int minutes) =>
      value.add(Duration(minutes: minutes));

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The next [count] days starting today (or [from]).
  static List<DateTime> nextDays(int count, {DateTime? from}) {
    final start = startOfDay(from ?? DateTime.now());
    return List.generate(count, (i) => start.add(Duration(days: i)));
  }

  /// `2026-10-24 14:00` → `14:00`.
  static String time(DateTime value) => DateFormat('HH:mm').format(value);

  /// → `Sat 24 Oct`.
  static String day(DateTime value) => DateFormat('EEE d MMM').format(value);

  /// → `Sat 24 Oct • 14:00`.
  static String dateTime(DateTime value) =>
      DateFormat('EEE d MMM • HH:mm').format(value);

  /// → `24 October 2026`.
  static String longDate(DateTime value) =>
      DateFormat('d MMMM yyyy').format(value);

  /// `Today`, `Tomorrow`, `Yesterday` or a formatted date.
  static String relativeDay(DateTime value, {DateTime? now}) {
    final reference = startOfDay(now ?? DateTime.now());
    final target = startOfDay(value);
    final difference = target.difference(reference).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    return day(value);
  }

  /// True when [value] lies in the past relative to [now].
  static bool isPast(DateTime value, {DateTime? now}) =>
      value.isBefore(now ?? DateTime.now());

  /// `14:00 – 16:00` label for a start/end pair.
  static String timeRange(DateTime start, DateTime end) =>
      '${time(start)} – ${time(end)}';
}
