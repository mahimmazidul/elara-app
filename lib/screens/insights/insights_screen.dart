import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database_helper.dart';
import '../../data/models/climate_snapshot.dart';
import '../../models/elara_result.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../theme/elara_theme.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/primitives.dart';
import 'charts.dart';
import '../../widgets/icons.dart';

/// Insights tab: three charts plus a plain-language summary of the prediction.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<ClimateSnapshot>? _climateHistory;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final all = await DatabaseHelper.instance.getAllClimateSnapshots();
      if (!mounted) return;
      setState(() {
        _climateHistory = all;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _climateHistory = const [];
        _loadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final cycles = context.watch<CycleProvider>();
    final prediction = context.watch<PredictionProvider>();
    final result = prediction.result;
    final lengths = cycles.completedLengths;

    return RefreshIndicator(
      color: tokens.accent,
      backgroundColor: tokens.bgCard,
      onRefresh: () async {
        await prediction.refresh(force: true);
        await _loadHistory();
      },
      child: ListView(
        padding: ElaraSpacing.pageInsets(context),
        children: [
          Text('Insights',
              style: type.headline(tokens.textPrimary, size: 28)),
          const SizedBox(height: ElaraSpacing.xxs),
          Text(
            'What the last few cycles actually did.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.xl),

          CycleLengthChart(lengths: lengths),
          const SizedBox(height: ElaraSpacing.md),

          MeanSdChart(
            mean: _mean(lengths),
            standardDeviation: _sampleSd(lengths),
            sampleCount: lengths.length,
          ),
          const SizedBox(height: ElaraSpacing.md),

          if (_loadingHistory)
            const ElaraCard(
              child: SizedBox(
                height: 120,
                child: Center(child: _SmallSpinner()),
              ),
            )
          else
            HeatIndexChart(
              points: _heatPoints(),
              bands: _bandsFor(result, cycles),
            ),
          const SizedBox(height: ElaraSpacing.xl),

          if (result != null) _PredictionSummary(result: result),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- statistics --

  static double _mean(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Sample standard deviation with the n − 1 denominator, the same estimator
  /// drip uses for cycle variability. Reporting the population SD on a handful
  /// of cycles would understate the spread.
  static double _sampleSd(List<int> values) {
    if (values.length < 2) return 0;
    final mean = _mean(values);
    final sumSquares = values
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b);
    return math.sqrt(sumSquares / (values.length - 1));
  }

  /// The last 30 days of cached heat index, oldest first.
  List<({DateTime date, double heatIndex})> _heatPoints() {
    final history = _climateHistory ?? const <ClimateSnapshot>[];
    if (history.isEmpty) return const [];
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return [
      for (final snapshot in history)
        if (!snapshot.date.isBefore(cutoff))
          (date: snapshot.date, heatIndex: snapshot.heatIndex),
    ];
  }

  /// Contiguous runs of the same phase across the charted days.
  List<({int startIndex, int endIndex, String phaseKey})> _bandsFor(
    ElaraResult? result,
    CycleProvider cycles,
  ) {
    final points = _heatPoints();
    final latest = cycles.latest;
    if (points.isEmpty || latest == null || result == null) return const [];

    final timeline = PhaseTimeline(
      lastPeriodStart: latest.startDate,
      cycleLength: result.cycleLength,
      periodDuration: latest.duration,
      today: DateTime.now(),
    );

    final bands = <({int startIndex, int endIndex, String phaseKey})>[];
    var runStart = 0;
    var currentKey = timeline.dayFor(points.first.date).key;

    for (var i = 1; i < points.length; i++) {
      final key = timeline.dayFor(points[i].date).key;
      if (key != currentKey) {
        bands.add((startIndex: runStart, endIndex: i - 1, phaseKey: currentKey));
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
}

class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.elara.accent,
      ),
    );
  }
}

/// Text summary of the latest prediction, with the confidence score and a
/// warning-coloured notice below 0.6.
class _PredictionSummary extends StatelessWidget {
  const _PredictionSummary({required this.result});

  final ElaraResult result;

  /// Below this, the ensemble's own score is not worth presenting as a date
  /// without a caveat.
  static const double lowConfidenceThreshold = 0.6;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final confidence = result.confidence;
    final isLow = confidence < lowConfidenceThreshold;
    final percent = (confidence * 100).round();
    final phaseKey = phaseKeyOf(result.phaseOrUnknown);

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ElaraOverline('Last prediction'),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            _sentence(result),
            style: type.body(tokens.textPrimary, size: 15),
          ),
          const SizedBox(height: ElaraSpacing.md),

          Row(
            children: [
              Text('Confidence',
                  style: type.label(tokens.textSecondaryStrong)),
              const Spacer(),
              NumberText('$percent', size: 18,
                  color: tokens.phaseText(phaseKey), suffix: '%'),
            ],
          ),
          const SizedBox(height: ElaraSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(ElaraRadii.bar),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: tokens.track,
              valueColor: AlwaysStoppedAnimation<Color>(
                isLow ? tokens.warning : tokens.phaseFill(phaseKey),
              ),
            ),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            'Ensemble score, not a probability. '
            '${result.contributingEngines.join(', ')}',
            style: type.caption(tokens.textSecondaryStrong),
          ),

          if (isLow) ...[
            const SizedBox(height: ElaraSpacing.md),
            Container(
              padding: const EdgeInsets.all(ElaraSpacing.md),
              decoration: BoxDecoration(
                color: tokens.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(ElaraRadii.chip),
                border: Border.all(
                  color: tokens.warning.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ElaraIcons.info, size: 16, color: tokens.warningText),
                  const SizedBox(width: ElaraSpacing.sm),
                  Expanded(
                    child: Text(
                      'Low confidence. The cycles so far disagree enough that '
                      'this date could be off by more than the stated window.',
                      style: type.caption(tokens.warningText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _sentence(ElaraResult result) {
    final date = result.nextPeriodDate;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final dateText = '${date.day} ${months[date.month - 1]} ${date.year}';
    final direction = result.daysUntilNextPeriod >= 0
        ? 'in ${result.daysUntilNextPeriod} '
            '${result.daysUntilNextPeriod == 1 ? 'day' : 'days'}'
        : '${result.daysUntilNextPeriod.abs()} '
            '${result.daysUntilNextPeriod.abs() == 1 ? 'day' : 'days'} ago';
    return 'The next period is estimated for $dateText, $direction, '
        'with a ±${result.windowDays} day window based on a '
        '${result.cycleLength} day cycle.';
  }
}
