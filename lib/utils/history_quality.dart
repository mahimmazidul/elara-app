import 'dart:math' as math;

import '../data/date_keys.dart';

/// One thing the app should say about the estimate it just produced.
///
/// A number presented on its own reads as a measurement. These are the two
/// occasions where the honest reading is different, and both are invisible in
/// the date itself: a wide window, and a gap worth checking.
enum HistoryNoteKind {
  /// The recorded intervals vary enough that a single date is not the story.
  spread,

  /// The latest interval is much longer than her recorded pattern. The note
  /// raises the possibility of a missed entry without deciding that for her.
  recordingGap,
}

class HistoryNote {
  const HistoryNote(this.kind, this.message);

  final HistoryNoteKind kind;
  final String message;
}

/// Notes about how much the estimate can be trusted, derived only from what the
/// user recorded.
///
/// Deliberately **not** a second opinion on the prediction. It does not change
/// the date or the window. It describes the variation and the gap in the
/// recorded dates without deciding whether a period was missed or her pattern
/// changed.
///
/// The one comparison made here is against her own history. Nothing is compared
/// to a textbook 28-day cycle, because this app is used by women whose normal is
/// not 28 and who are tired of being told so.
class HistoryQuality {
  const HistoryQuality._();

  /// Below this many completed intervals there is no her-normal to compare to,
  /// and saying anything about variability would be inventing a baseline.
  static const int minimumIntervalsForSpread = 3;

  /// A window at least this wide is stated rather than left to the reader.
  static const int wideWindowDays = 8;

  /// How much longer than her own usual interval raises a recording question.
  ///
  /// Twice the median is not a clinical threshold. It only describes the
  /// difference in the dates she recorded. A long cycle that is genuinely hers
  /// stops being flagged once it becomes part of her recorded pattern.
  static const double gapRatio = 2.0;

  /// Finds the notes worth showing for this history.
  ///
  /// [starts] must be the recorded period starts, oldest first, as stored.
  /// [windowDays] is the radius the engine returned for this forecast.
  static List<HistoryNote> notesFor({
    required List<DateTime> starts,
    required int windowDays,
  }) {
    final notes = <HistoryNote>[];

    final intervals = <int>[];
    for (var i = 1; i < starts.length; i++) {
      final length = daysBetween(dateOnly(starts[i - 1]), dateOnly(starts[i]));
      if (length > 0) intervals.add(length);
    }

    if (intervals.length >= minimumIntervalsForSpread &&
        windowDays >= wideWindowDays) {
      final median = _median(intervals);
      notes.add(HistoryNote(
        HistoryNoteKind.spread,
        'Her recorded intervals vary around $median days, so Elara is giving a '
        'range rather than a day. That range is the estimate.',
      ));
    }

    if (intervals.length >= 2) {
      // Only the most recent interval is commented on: an old gap is history,
      // and re-raising it every day would be nagging rather than noticing.
      //
      // The comparison is against the median of *all* her intervals, which
      // includes this one. That is what makes the note fade on its own: one
      // long interval among several stays an outlier, but two of them move the
      // median. The app can flag the difference; it cannot tell a missed entry
      // from a genuine change in her cycle.
      final latest = intervals.last;
      final median = _median(intervals);
      if (median > 0 && latest >= median * gapRatio && latest >= 30) {
        notes.add(HistoryNote(
          HistoryNoteKind.recordingGap,
          'The last gap was $latest days, about twice her usual $median. A '
          'period may not have been recorded, or her pattern may have changed. '
          'Check the dates before relying on this estimate.',
        ));
      }
    }

    return notes;
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }
}

/// Convenience for a value already in hand elsewhere.
int medianInterval(List<int> intervals) {
  if (intervals.isEmpty) return 0;
  final sorted = [...intervals]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : ((sorted[middle - 1] + sorted[middle]) / 2).round();
}

/// Exposed for the tests that describe the arithmetic in words.
int gapThresholdFor(int medianDays) =>
    math.max(30, (medianDays * HistoryQuality.gapRatio).round());
