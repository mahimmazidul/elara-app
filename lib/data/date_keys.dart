/// Canonical string encodings used by the database layer.
///
/// SQLite has no date type, so Elara stores calendar dates as `yyyy-MM-dd`
/// and instants as ISO-8601. Keeping the two conversions in one place stops
/// the app from mixing formats between tables and queries.
library;

/// `yyyy-MM-dd` for a calendar date, in local time.
///
/// Calendar dates are intentionally timezone-free: a period start is a day on
/// the user's wall calendar, not an instant, so it must not shift when the
/// device timezone changes.
String dateKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// ISO-8601 for an instant, e.g. `2026-11-08T14:23:55.000`.
String timestampKey(DateTime instant) => instant.toIso8601String();

/// Parses a `yyyy-MM-dd` key back into local midnight.
DateTime parseDateKey(String value) {
  final parsed = DateTime.parse(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Strips the time component from a [DateTime], in local time.
DateTime dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Whole calendar days from [start] to [end], ignoring time of day.
int daysBetween(DateTime start, DateTime end) =>
    dateOnly(end).difference(dateOnly(start)).inDays;
