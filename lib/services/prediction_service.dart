import 'package:elara_core/elara_core.dart' as core;

import '../data/database_helper.dart';
import '../data/models/cycle_entry.dart';
import '../models/elara_result.dart';
import 'climate_service.dart';

/// Runs the elara-core pipeline over locally stored history.
///
/// The service is deliberately thin: it reads rows, adapts them to
/// [core.CycleRecord], and hands them to the engine. All cycle reasoning lives
/// in elara-core so that the app and the library cannot drift apart.
///
/// Nothing here throws. Storage errors and engine rejections downgrade to
/// `null` or to a result with a null [ElaraResult.phase] plus a reason, because
/// a prediction screen that crashes offline is worse than one that says "not
/// enough history yet".
class PredictionService {
  PredictionService({
    DatabaseHelper? database,
    ClimateService? climateService,
    core.ElaraFusion? fusion,
    DateTime Function()? clock,
  })  : _database = database ?? DatabaseHelper.instance,
        _climateService = climateService ?? ClimateService(),
        _fusion = fusion ?? core.ElaraFusion(),
        _clock = clock ?? DateTime.now;

  final DatabaseHelper _database;
  final ClimateService _climateService;
  final core.ElaraFusion _fusion;
  final DateTime Function() _clock;

  /// elara-core's classifier requires at least this many days per cycle.
  static const int minimumClassifiableCycleLength = 15;

  /// Computes the current forecast.
  ///
  /// Returns null when there is not a single recorded period, or when the
  /// engine cannot forecast (for example, only one cycle exists and no engine
  /// has anything to extrapolate from).
  Future<ElaraResult?> predict({DateTime? date}) async {
    final now = date ?? _clock();

    final List<CycleEntry> entries;
    try {
      // get :all cycles is already ordered oldest-first, as core requires.
      entries = await _database.getAllCycles();
    } catch (_) {
      return null;
    }

    if (entries.isEmpty) return null;

    final history = _toCycleRecords(entries);
    if (history.isEmpty) return null;

    final core.PredictionResult? prediction;
    try {
      prediction = _fusion.predict(history);
    } catch (_) {
      // core throws on inconsistent engine output (a bug, not user input).
      return null;
    }
    if (prediction == null) return null;

    final environment = await _climateService.getTodayClimate(date: now);

    // Severity is independent of the phase, so compute it first; a phase
    // failure should not cost the user their environmental guidance.
    core.SeverityResult? severity;
    try {
      severity = core.SeverityModifier().calculate(
        environment.toEnvironmentConditions(),
      );
    } catch (_) {
      severity = null;
    }

    final classification = _classify(
      history: history,
      lastEntry: entries.last,
      cycleLength: prediction.cycleLength,
      date: now,
    );

    core.ActionResult? action;
    if (classification.phase != null && severity != null) {
      try {
        action = core.ActionEngine().recommend(
          phase: classification.phase!,
          severity: severity,
        );
      } catch (_) {
        action = null;
      }
    }

    return ElaraResult(
      prediction: prediction,
      environment: environment,
      generatedAt: now,
      phase: classification.phase,
      severity: severity,
      action: action,
      unavailableReason: classification.reason,
    );
  }

  /// Adapts rows to engine records, dropping anything core would reject
  /// (a non-positive duration, or duplicate/out-of-order starts) instead of
  /// failing the whole forecast.
  List<core.CycleRecord> _toCycleRecords(List<CycleEntry> entries) {
    final records = <core.CycleRecord>[];
    DateTime? previous;
    for (final entry in entries) {
      final duration = entry.duration;
      // core requires periodDuration >= 1 when it is present.
      final safeDuration = (duration != null && duration >= 1) ? duration : null;
      try {
        final record = core.CycleRecord(
          startDate: entry.startDate,
          periodDuration: safeDuration,
        );
        // Completed-cycle maths in core requires strictly increasing starts.
        if (previous != null && !record.startDate.isAfter(previous)) continue;
        records.add(record);
        previous = record.startDate;
      } catch (_) {
        continue;
      }
    }
    return records;
  }

  ({core.PhaseResult? phase, String? reason}) _classify({
    required List<core.CycleRecord> history,
    required CycleEntry lastEntry,
    required int cycleLength,
    required DateTime date,
  }) {
    if (cycleLength < minimumClassifiableCycleLength) {
      return (
        phase: null,
        reason: 'The estimated cycle is shorter than '
            '$minimumClassifiableCycleLength days, so no phase can be assigned.',
      );
    }

    final duration = lastEntry.duration;
    if (duration != null && duration > cycleLength) {
      return (
        phase: null,
        reason: 'The recorded period is longer than the estimated cycle, '
            'so the phases would overlap.',
      );
    }

    try {
      final phase = core.PhaseClassifier().classify(
        lastPeriod: history.last,
        cycleLength: cycleLength,
        date: date,
      );
      return (phase: phase, reason: null);
    } on ArgumentError catch (error) {
      return (phase: null, reason: error.message.toString());
    } catch (_) {
      return (
        phase: null,
        reason: 'The current date could not be placed in the cycle.',
      );
    }
  }

  void dispose() => _climateService.dispose();
}
