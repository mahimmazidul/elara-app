import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/elara_result.dart';
import '../../providers/prediction_provider.dart';
import '../../theme/elara_theme.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';

/// What the estimate is, what produced it, and how much of it to believe.
///
/// This paragraph used to sit at the foot of the Insights tab, under three
/// charts, where the number that most needed a caveat was the one furthest from
/// the top of the screen. It is now a page of its own, opened from a row that
/// states the score before you tap it.
class PredictionPage extends StatelessWidget {
  const PredictionPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const PredictionPage());
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<PredictionProvider>().result;
    final tokens = context.elara;
    final type = context.type;

    return ElaraSubPage(
      title: 'The estimate',
      subtitle:
          'Produced on this phone from recorded period starts and nothing '
          'else.',
      children: [
        if (result == null)
          ElaraGlass(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ElaraIcons.info,
                  size: 18,
                  color: tokens.textSecondaryStrong,
                ),
                const SizedBox(width: ElaraSpacing.sm),
                Expanded(
                  child: Text(
                    'There is no forecast at the moment. That is deliberate: '
                    'Elara stops estimating when prediction is switched off, '
                    'when a pregnancy or loss is recorded, or when there is not '
                    'enough history to estimate from. The reason is on the '
                    'Today screen, and it is never an error.',
                    style: type.body(tokens.textSecondaryStrong),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _Summary(result: result),
          const SizedBox(height: ElaraSpacing.lg),
          const _Method(),
        ],
      ],
    );
  }
}

/// Text summary of the latest prediction, with the confidence score and a
/// warning-coloured notice below 0.6.
class _Summary extends StatelessWidget {
  const _Summary({required this.result});

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

    return ElaraGlass(
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
              Text('Confidence', style: type.label(tokens.textSecondaryStrong)),
              const Spacer(),
              NumberText(
                '$percent',
                size: 18,
                color: tokens.phaseText(phaseKey),
                suffix: '%',
              ),
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
            'Produced by Elara\u2019s own ensemble engine (elara-core), '
            'reflecting how closely your recorded cycles agree.',
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
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

/// Where the number comes from, in the order the engines contribute.
class _Method extends StatelessWidget {
  const _Method();

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return ElaraGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it was made', style: type.subtitle(tokens.textPrimary)),
          const SizedBox(height: ElaraSpacing.xs),
          Text(
            'Elara uses its own ensemble engine (elara-core), developed from '
            'foundational work in OpenCiclo and Flowlytics. It combines '
            'long-term cycle averages, recency-weighted trends, and cycle '
            'variability from your recorded dates on this phone. The '
            'confidence score reflects how closely those signals agree with '
            'one another.',
            style: type.body(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.md),
          Text(
            'A short history means a wide window, and an irregular one means a '
            'wider window still. If the window is too wide to be useful, the '
            'app says that instead of narrowing it to look confident.',
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
      ),
    );
  }
}
