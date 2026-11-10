import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database_helper.dart';
import '../../data/models/climate_snapshot.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';
import 'charts.dart';
import 'insights_stats.dart';

/// Heat index over the last month, with the estimated phases drawn across it.
///
/// The bands are estimates and the chart says so. The point of putting the two
/// together is the question a reader actually has in a Dhaka summer — *is the
/// week I feel worst the same week it is hottest, or is that my cycle?* — and the
/// answer is only honest if the phase band is labelled as arithmetic.
class HeatCyclePage extends StatefulWidget {
  const HeatCyclePage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const HeatCyclePage());
  }

  @override
  State<HeatCyclePage> createState() => _HeatCyclePageState();
}

class _HeatCyclePageState extends State<HeatCyclePage> {
  List<ClimateSnapshot>? _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await DatabaseHelper.instance.getAllClimateSnapshots();
      if (!mounted) return;
      setState(() {
        _history = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _history = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final cycles = context.watch<CycleProvider>();
    final result = context.watch<PredictionProvider>().result;
    final points = InsightsStats.heatPoints(_history);
    final bands = InsightsStats.bandsFor(
      result: result,
      cycles: cycles,
      points: points,
    );

    return ElaraSubPage(
      title: 'Heat and the cycle',
      subtitle:
          'Recorded on this phone each time the app checked the forecast. The '
          'phase bands are estimates from recorded history, not measurements.',
      children: [
        if (_loading)
          const ElaraGlass(
            child: SizedBox(height: 120, child: Center(child: _SmallSpinner())),
          )
        else ...[
          HeatIndexChart(points: points, bands: bands),
          const SizedBox(height: ElaraSpacing.lg),
          ElaraGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading it',
                  style: type.subtitle(tokens.textPrimary, size: 15),
                ),
                const SizedBox(height: ElaraSpacing.xs),
                Text(
                  'The line is the heat index — temperature and humidity '
                  'together, which is what the body actually deals with. In '
                  'Dhaka it runs far above the air temperature for much of the '
                  'year, and a hot, humid week reduces how well anyone '
                  'tolerates exertion, cramps included.',
                  style: type.body(tokens.textSecondaryStrong),
                ),
                if (points.isEmpty) ...[
                  const SizedBox(height: ElaraSpacing.sm),
                  Text(
                    'No snapshots yet. The chart fills in as the app is opened '
                    'with location set and a connection available.',
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
                if (bands.isEmpty && points.isNotEmpty) ...[
                  const SizedBox(height: ElaraSpacing.sm),
                  Text(
                    'No phase bands are drawn: there is no current estimate to '
                    'place them from, and a guessed band would look the same as '
                    'a measured one.',
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
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
