import 'package:hijri/hijri_calendar.dart';

/// Islamic (Hijri) calendar date, computed locally by the `hijri` package.
///
/// `HijriCalendar.fromDate` fills the object's fields as a side effect of
/// conversion rather than returning structured data, so this wrapper exists to
/// give the UI one immutable, null-safe value and a single formatted label.
///
/// The package uses the Umm al-Qura calendar. That is a calculated calendar,
/// not local crescent sighting, so around the start of a month it can be one day
/// off what a user in Bangladesh observes. The UI presents it as an
/// approximation for that reason.
class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
  });

  final int year;
  final int month;
  final int day;
  final String monthName;

  /// e.g. "27 Jumada al-Awwal 1448".
  String get formatted => '$day $monthName $year';

  /// e.g. "27 Jum. I 1448".
  String get short => '$day $monthName $year';

  /// Computes the Hijri date for [date].
  ///
  /// Never throws: if the package fails on an out-of-range date, a placeholder
  /// is returned so the Today strip can still render.
  factory HijriDate.forDate(DateTime date) {
    try {
      final hijri = HijriCalendar.fromDate(date);
      return HijriDate(
        year: hijri.hYear,
        month: hijri.hMonth,
        day: hijri.hDay,
        monthName: hijri.getLongMonthName(),
      );
    } catch (_) {
      return const HijriDate(
        year: 0,
        month: 0,
        day: 0,
        monthName: 'Hijri date unavailable',
      );
    }
  }

  @override
  String toString() => formatted;
}

/// The 12 Hijri month names, for reference and for the calendar screen.
const List<String> hijriMonthNames = [
  'Muharram',
  'Safar',
  "Rabi' al-awwal",
  "Rabi' al-thani",
  'Jumada al-awwal',
  'Jumada al-thani',
  'Rajab',
  "Sha'ban",
  'Ramadan',
  'Shawwal',
  "Dhu al-Qi'dah",
  'Dhu al-Hijjah',
];
