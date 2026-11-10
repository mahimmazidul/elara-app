import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cycle_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';
import 'charts.dart';
import 'insights_stats.dart';

/// How long her cycles have been, and how much they vary.
///
/// The two charts were stacked on the Insights tab with nothing explaining why
/// they belong together. They belong together because they answer one question:
/// the first is the history, the second is the uncertainty that history implies.
/// A cycle length of 28 days means one thing with a spread of half a day and
/// something quite different with a spread of nine.
class CycleLengthPage extends StatelessWidget {
  const CycleLengthPage({super.key, this.startAtSpread = false});

  /// Open scrolled to the spread chart, for the reader who tapped "How steady it
  /// is" rather than "Cycle length".
  final bool startAtSpread;

  static Route<void> route(BuildContext context, {bool startAtSpread = false}) {
    return MaterialPageRoute<void>(
      builder: (_) => CycleLengthPage(startAtSpread: startAtSpread),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final lengths = context.watch<CycleProvider>().completedLengths;

    final spreadKey = GlobalKey();

    // Scrolling to the second chart happens once, after the first frame, so the
    // reader arrives where the row promised rather than at the top of a page
    // they have already seen.
    if (startAtSpread) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = spreadKey.currentContext;
        if (target == null) return;
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 260),
          alignment: 0.05,
        );
      });
    }

    return ElaraSubPage(
      title: 'Cycle length',
      subtitle:
          'Taken from the gap between one recorded period start and the next. '
          'A cycle is only counted once both ends are recorded.',
      children: [
        CycleLengthChart(lengths: lengths),
        const SizedBox(height: ElaraSpacing.lg),
        KeyedSubtree(key: spreadKey, child: const SizedBox.shrink()),
        MeanSdChart(
          mean: InsightsStats.mean(lengths),
          standardDeviation: InsightsStats.sampleSd(lengths),
          sampleCount: lengths.length,
        ),
        const SizedBox(height: ElaraSpacing.lg),

        // The part that matters and that a chart cannot say: what the spread
        // does to the forecast.
        ElaraGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What this does to the forecast',
                style: type.subtitle(tokens.textPrimary, size: 15),
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                lengths.length < 2
                    ? 'With one cycle or none there is nothing to compare, so '
                          'the estimate falls back to a typical length and says '
                          'so. The window widens as cycles are recorded.'
                    : 'The wider the spread, the wider the window around the '
                          'estimated date. Elara widens it rather than quoting a '
                          'date it cannot hold to, which is why a steady history '
                          'gives a window of a day or two and an irregular one '
                          'gives a week.',
                style: type.body(tokens.textSecondaryStrong),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
