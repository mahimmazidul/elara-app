import 'dart:math' as math;

import '../../data/models/climate_snapshot.dart';
import '../../models/elara_result.dart';
import '../../providers/cycle_provider.dart';
import '../../utils/phase_timeline.dart';

/// Statistics and series shared by the Insights hub and the pages behind it.
///
/// These used to be private methods on the Insights screen, which was fine while
/// there was one screen. Now that the hub shows a summary and three pages show
/// the detail, they live here so the hub's one-line summaries and the charts
/// cannot disagree about what the mean is.
class InsightsStats {
  const InsightsStats._();

  static double mean(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Sample standard deviation with the n − 1 denominator, the same estimator
  /// DRIP uses for cycle variability. Reporting the population SD on a handful
  /// of cycles would understate the spread.
  static double sampleSd(List<int> values) {
    if (values.length < 2) return 0;
    final average = mean(values);
    final sumSquares = values
        .map((v) => (v - average) * (v - average))
        .reduce((a, b) => a + b);
    return math.sqrt(sumSquares / (values.length - 1));
  }

  /// The last [days] of cached heat index, oldest first.
  static List<({DateTime date, double heatIndex})> heatPoints(
    List<ClimateSnapshot>? history, {
    DateTime? today,
    int days = 30,
  }) {
    final snapshots = history ?? const <ClimateSnapshot>[];
    if (snapshots.isEmpty) return const [];
    final cutoff = (today ?? DateTime.now()).subtract(Duration(days: days));
    return [
      for (final snapshot in snapshots)
        if (!snapshot.date.isBefore(cutoff))
          (date: snapshot.date, heatIndex: snapshot.heatIndex),
    ];
  }

  /// Contiguous runs of the same phase across the charted days.
  ///
  /// Empty rather than wrong when any part of the picture is missing: no
  /// climate history, no recorded period, or no estimate all mean there is no
  /// honest band to draw, and a guessed band on a chart is indistinguishable
  /// from a measured one.
  static List<({int startIndex, int endIndex, String phaseKey})> bandsFor({
    required ElaraResult? result,
    required CycleProvider cycles,
    required List<({DateTime date, double heatIndex})> points,
    DateTime? today,
  }) {
    final latest = cycles.latest;
    if (points.isEmpty || latest == null || result == null) return const [];

    final timeline = PhaseTimeline(
      lastPeriodStart: latest.startDate,
      cycleLength: result.cycleLength,
      periodDuration: latest.duration,
      today: today ?? DateTime.now(),
    );

    final bands = <({int startIndex, int endIndex, String phaseKey})>[];
    var runStart = 0;
    var currentKey = timeline.dayFor(points.first.date).key;

    for (var i = 1; i < points.length; i++) {
      final key = timeline.dayFor(points[i].date).key;
      if (key != currentKey) {
        bands.add((
          startIndex: runStart,
          endIndex: i - 1,
          phaseKey: currentKey,
        ));
        runStart = i;
        currentKey = key;
      }
    }
    bands.add((
      startIndex: runStart,
      endIndex: points.length - 1,
      phaseKey: currentKey,
    ));
    return bands;
  }

  /// "4 cycles · 27.8 days on average", or a plain statement that there are not
  /// yet enough.
  static String cycleSummary(List<int> lengths) {
    if (lengths.isEmpty) return 'No completed cycles yet';
    if (lengths.length == 1) {
      return '1 completed cycle · nothing to compare yet';
    }
    final average = mean(lengths).toStringAsFixed(1);
    return '${lengths.length} completed cycles · $average days on average';
  }

  /// "Spread 2.4 days (1 SD)" — the number that decides whether the window in
  /// the next-period estimate is two days or eight.
  static String spreadSummary(List<int> lengths) {
    if (lengths.length < 2) return 'Needs two completed cycles';
    return 'Spread ${sampleSd(lengths).toStringAsFixed(1)} days (1 SD)';
  }
}
