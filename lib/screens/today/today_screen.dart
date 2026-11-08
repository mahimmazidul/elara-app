import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/date_keys.dart';
import '../../models/elara_result.dart';
import '../../providers/climate_provider.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../theme/elara_theme.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/phase_chip.dart';
import '../../widgets/primitives.dart';
import 'action_cards.dart';
import 'climate_strip.dart';
import 'lunar_strip.dart';
import 'onboarding_card.dart';

/// The Today tab.
///
/// Three states, in order of precedence:
///   1. no history at all -> [OnboardingCard] full screen;
///   2. history but no forecast yet (a single recorded start, say) -> a short
///      explanation rather than fabricated numbers;
///   3. a forecast -> phase, countdown, climate, guidance, lunar strip.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cycles = context.watch<CycleProvider>();
    final prediction = context.watch<PredictionProvider>();
    final tokens = context.elara;

    if (cycles.isLoading && cycles.isEmpty) {
      return const _Loading();
    }
    if (cycles.isEmpty) {
      return const OnboardingCard();
    }

    final result = prediction.result;
    if (result == null) {
      if (prediction.isLoading) return const _Loading();
      return _NeedsMoreHistory(
        message: prediction.lastError ??
            'A forecast needs at least two recorded period starts. '
                'Log the next one when it begins.',
      );
    }

    return RefreshIndicator(
      color: tokens.accent,
      backgroundColor: tokens.bgCard,
      onRefresh: () async {
        await prediction.refresh(force: true);
        if (context.mounted) {
          await context.read<ClimateProvider>().load();
        }
      },
      child: _TodayContent(result: result),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Center(
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
      ),
    );
  }
}

class _NeedsMoreHistory extends StatelessWidget {
  const _NeedsMoreHistory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final latest = context.watch<CycleProvider>().latest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ElaraSpacing.lg,
        ElaraSpacing.lg,
        ElaraSpacing.lg,
        ElaraSpacing.xxl,
      ),
      children: [
        Text('Today', style: type.headline(tokens.textPrimary, size: 28)),
        const SizedBox(height: ElaraSpacing.xs),
        Text(
          _formatLongDate(DateTime.now()),
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.xl),
        EmptyState(
          icon: Icons.timeline_outlined,
          title: 'Not enough history yet',
          message: message,
        ),
        if (latest != null) ...[
          const SizedBox(height: ElaraSpacing.md),
          ElaraCard(
            child: Row(
              children: [
                Icon(Icons.event_available_outlined,
                    size: 18, color: tokens.textSecondaryStrong),
                const SizedBox(width: ElaraSpacing.sm),
                Expanded(
                  child: Text(
                    'Last start recorded: ${_formatShortDate(latest.startDate)}',
                    style: type.body(tokens.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.result});

  final ElaraResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final now = DateTime.now();

    final phaseKey = phaseKeyOf(result.phaseOrUnknown);
    final phaseLabel = result.phase == null
        ? 'Unclassified'
        : phaseLabelOf(result.phase!.phase);

    final latest = context.watch<CycleProvider>().latest;
    final daysSinceStart =
        latest == null ? null : daysBetween(latest.startDate, now);

    final daysUntil = result.daysUntilNextPeriod;
    final isLate = daysUntil < 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ElaraSpacing.lg,
        ElaraSpacing.lg,
        ElaraSpacing.lg,
        ElaraSpacing.xxl,
      ),
      children: [
        // ---- header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today',
                      style: type.headline(tokens.textPrimary, size: 28)),
                  const SizedBox(height: ElaraSpacing.xxs),
                  Text(
                    _formatLongDate(now),
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.lg),

        // ---- phase chip
        Row(
          children: [
            PhaseChip(
              label: phaseLabel,
              phaseKey: phaseKey,
              cycleDay: result.phase?.cycleDay,
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- countdown
        ElaraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElaraOverline(
                isLate ? 'Estimated start has passed' : 'Next period in',
              ),
              const SizedBox(height: ElaraSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  NumberText(
                    isLate ? '${daysUntil.abs()}' : '$daysUntil',
                    style: type.displayNumber(
                      isLate
                          ? tokens.warningText
                          : tokens.phaseText(phaseKey),
                      size: 60,
                    ),
                  ),
                  const SizedBox(width: ElaraSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      isLate
                          ? (daysUntil.abs() == 1 ? 'day late' : 'days late')
                          : (daysUntil == 1 ? 'day' : 'days'),
                      style: type.subtitle(tokens.textSecondaryStrong, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                'Estimated ${_formatShortDate(result.nextPeriodDate)} '
                '± ${result.windowDays} ${result.windowDays == 1 ? 'day' : 'days'}',
                style: type.body(tokens.textSecondaryStrong),
              ),
              if (daysSinceStart != null) ...[
                const SizedBox(height: ElaraSpacing.md),
                Container(height: 1, color: tokens.divider),
                const SizedBox(height: ElaraSpacing.md),
                Row(
                  children: [
                    Text(
                      'Days since last period started',
                      style: type.label(tokens.textSecondaryStrong),
                    ),
                    const Spacer(),
                    NumberText('$daysSinceStart', size: 16),
                  ],
                ),
              ],
              if (result.unavailableReason != null) ...[
                const SizedBox(height: ElaraSpacing.md),
                Text(
                  result.unavailableReason!,
                  style: type.caption(tokens.textSecondaryStrong),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.md),

        // ---- climate
        ClimateStrip(snapshot: result.environment, phaseKey: phaseKey),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- guidance
        const SectionTitle('Today\u2019s guidance'),
        ActionCards(
          action: result.action,
          phaseKey: phaseKey,
          unavailableReason: result.unavailableReason,
        ),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- lunar strip
        LunarStrip(date: now),
        const SizedBox(height: ElaraSpacing.md),
        Text(
          'Calendar estimates and traditional calendars, not medical or '
          'religious guidance.',
          style: type.caption(tokens.textSecondaryStrong),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatLongDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String _formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1].substring(0, 3)} ${date.year}';
