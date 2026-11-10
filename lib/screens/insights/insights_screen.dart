import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database_helper.dart';
import '../../data/models/climate_snapshot.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import 'cycle_length_page.dart';
import 'heat_cycle_page.dart';
import 'insights_stats.dart';
import 'prediction_page.dart';

/// The Insights hub.
///
/// This was one scroll: a cycle-length chart, a mean-and-spread chart, a heat
/// chart with phase bands across it, and a paragraph about the last prediction.
/// Every one of those is worth having, and read in that order they answered a
/// question nobody had asked. A reader who opens Insights usually has one of
/// three in mind — *how regular am I*, *how sure is this date*, *does the heat
/// have anything to do with it* — and had to scroll past two charts to reach the
/// one that answered it.
///
/// So the tab is now a hub, in the same shape as Settings: three subjects, each
/// with the line that tells you what is inside, and a page behind it holding
/// only that subject. Nothing was removed.
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
    final lengths = cycles.completedLengths;
    final points = InsightsStats.heatPoints(_climateHistory);

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
          Text('Insights', style: type.headline(tokens.textPrimary, size: 28)),
          const SizedBox(height: ElaraSpacing.xxs),
          Text(
            'What the last few cycles actually did.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.xl),

          const _GroupLabel('Her cycles'),
          ElaraGlassGroup(
            children: [
              ElaraListRow(
                title: 'Cycle length',
                subtitle: InsightsStats.cycleSummary(lengths),
                icon: ElaraIcons.trend,
                onTap: () =>
                    Navigator.of(context).push(CycleLengthPage.route(context)),
              ),
              ElaraListRow(
                title: 'How steady it is',
                subtitle: InsightsStats.spreadSummary(lengths),
                icon: ElaraIcons.observation,
                onTap: () => Navigator.of(
                  context,
                ).push(CycleLengthPage.route(context, startAtSpread: true)),
              ),
            ],
          ),

          const SizedBox(height: ElaraSpacing.xl),
          const _GroupLabel('The estimate'),
          ElaraGlassGroup(
            children: [
              ElaraListRow(
                title: 'How the prediction was made',
                subtitle: _predictionSummary(context),
                icon: ElaraIcons.timeline,
                onTap: () =>
                    Navigator.of(context).push(PredictionPage.route(context)),
              ),
            ],
          ),

          const SizedBox(height: ElaraSpacing.xl),
          const _GroupLabel('Around her'),
          ElaraGlassGroup(
            children: [
              ElaraListRow(
                title: 'Heat and the cycle',
                subtitle: _loadingHistory
                    ? 'Reading the last 30 days…'
                    : (points.isEmpty
                          ? 'No weather recorded yet'
                          : '${points.length} days of heat index, with the phases '
                                'drawn across them'),
                icon: ElaraIcons.weather,
                onTap: () =>
                    Navigator.of(context).push(HeatCyclePage.route(context)),
              ),
            ],
          ),

          const SizedBox(height: ElaraSpacing.xl),
          Text(
            'Everything here is computed on this phone from the dates she has '
            'recorded. The charts show what the history did; the estimate below '
            'them says how much to trust a forecast made from it.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }

  /// One line about the estimate, phrased so that having no forecast reads as a
  /// choice rather than a failure.
  String _predictionSummary(BuildContext context) {
    final prediction = context.watch<PredictionProvider>();
    final result = prediction.result;
    if (result == null) {
      return 'No forecast right now · see why';
    }
    final percent = (result.confidence * 100).round();
    final window = result.windowDays;
    return '$percent% ensemble score · ±$window ${window == 1 ? 'day' : 'days'}';
  }
}

/// A small heading above a group of rows, matching the settings hub.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Padding(
      padding: const EdgeInsets.only(
        left: ElaraSpacing.xxs,
        bottom: ElaraSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.type
            .caption(tokens.textSecondaryStrong, size: 11)
            .copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600),
      ),
    );
  }
}
