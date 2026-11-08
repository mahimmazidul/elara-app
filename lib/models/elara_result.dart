import 'package:elara_core/elara_core.dart' as core;

import '../data/date_keys.dart';
import '../data/models/climate_snapshot.dart';

/// Everything Elara knows about the user's cycle right now.
///
/// elara-core exposes the forecast, the phase, the environmental severity and
/// the suggestions as four separate calls with four separate return types. This
/// aggregate is the app's single answer object: providers and screens depend on
/// one immutable value instead of re-deriving the same pipeline everywhere.
///
/// [phase], [severity] and [action] are nullable because they are genuinely
/// unavailable in edge cases: elara-core's classifier rejects a cycle shorter
/// than 15 days or a date before the last recorded period start, and the action
/// engine declines to suggest anything for an unknown phase. When that happens,
/// [unavailableReason] explains why rather than the app inventing a phase.
class ElaraResult {
  const ElaraResult({
    required this.prediction,
    required this.environment,
    required this.generatedAt,
    this.phase,
    this.severity,
    this.action,
    this.unavailableReason,
  });

  /// Consensus forecast from the ensemble. Never null: a result only exists
  /// when at least one engine produced a forecast.
  final core.PredictionResult prediction;

  /// The environmental input the severity was calculated from.
  final ClimateSnapshot environment;

  final DateTime generatedAt;

  final core.PhaseResult? phase;
  final core.SeverityResult? severity;
  final core.ActionResult? action;

  /// Plain-language explanation when [phase] could not be classified.
  final String? unavailableReason;

  /// Estimated next period start.
  DateTime get nextPeriodDate => prediction.predictedDate;

  /// Days until the next estimated start; negative when the estimate is past.
  int get daysUntilNextPeriod =>
      daysBetween(generatedAt, prediction.predictedDate);

  /// Inclusive uncertainty window around [nextPeriodDate].
  core.DateRange get window => prediction.window;

  int get cycleLength => prediction.cycleLength;

  /// Heuristic ensemble score in 0..1. Not a calibrated probability.
  double get confidence => prediction.confidence;

  int get windowDays => prediction.windowDays;

  /// True when the user has already logged a start, so this is an observation
  /// rather than a forecast.
  bool get isObserved => prediction.isObserved;

  core.CyclePhase get phaseOrUnknown => phase?.phase ?? core.CyclePhase.unknown;

  /// Engine names that contributed, for the transparency panel.
  List<String> get contributingEngines => prediction.contributingEngines
      .map((engine) => engine.engineName)
      .toList(growable: false);

  /// Convenience flags that the UI will need; kept here so screens never
  /// re-interpret core enums themselves.
  bool get isFertileWindow => phase?.isFertile ?? false;
  bool get isOverdue => daysUntilNextPeriod < 0;
  bool get hasLowConfidence => confidence < 0.5;
  bool get isEnvironmentalFallback => environment.isFallback;

  @override
  String toString() => 'ElaraResult(next: ${dateKey(nextPeriodDate)}, '
      'len: $cycleLength, +/-$windowDays d, conf: '
      '${confidence.toStringAsFixed(3)}, phase: $phaseOrUnknown)';
}
