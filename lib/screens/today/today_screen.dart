import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/elara_result.dart';
import '../../providers/climate_provider.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../services/care_recommender.dart';
import '../../theme/elara_motion.dart';
import '../../theme/elara_theme.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/motion.dart';
import '../../widgets/phase_chip.dart';
import '../../widgets/primitives.dart';
import 'action_cards.dart';
import 'care_suggestions.dart';
import 'day_notes.dart';
import 'climate_strip.dart';
import 'lunar_strip.dart';
import 'onboarding_card.dart';
import '../../widgets/icons.dart';

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
      padding: ElaraSpacing.pageInsets(context),
      children: [
        Text('Today', style: type.headline(tokens.textPrimary, size: 28)),
        const SizedBox(height: ElaraSpacing.xs),
        Text(
          _formatLongDate(DateTime.now()),
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.xl),
        EmptyState(
          icon: ElaraIcons.timeline,
          title: 'Not enough history yet',
          message: message,
        ),
        if (latest != null) ...[
          const SizedBox(height: ElaraSpacing.md),
          ElaraCard(
            child: Row(
              children: [
                Icon(ElaraIcons.recorded,
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

    final preferences = context.watch<PreferencesProvider>();
    final symptoms = context.watch<SymptomsProvider>();

    final daysUntil = result.daysUntilNextPeriod;
    final isLate = daysUntil < 0;

    // Recomputed on every build from the stored preferences and recent
    // symptoms, so a change made on another screen is reflected here without a
    // cache to invalidate. It is a handful of comparisons, not a computation.
    final suggestions = const CareRecommender().recommend(
      preferences: preferences.all,
      recentSymptoms: symptoms.recent,
      climate: result.environment,
      today: now,
    );

    return ListView(
      padding: ElaraSpacing.pageInsets(context),
      children: [
        // The header fades in once when the screen opens. A fade says "this is
        // ready" without pulling the eye somewhere; a slide would do the
        // opposite every time the tab is opened. With the platform's
        // "Remove animations" setting on, the content is simply there.
        ElaraFadeIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- header: date and estimated phase, one line each
              Text('Today', style: type.headline(tokens.textPrimary, size: 28)),
              const SizedBox(height: ElaraSpacing.xxs),
              Text(
                _formatLongDate(now),
                style: type.caption(tokens.textSecondaryStrong),
              ),
              const SizedBox(height: ElaraSpacing.md),
              Row(
                children: [
                  Flexible(
                    child: PhaseChip(
                      label: phaseLabel,
                      phaseKey: phaseKey,
                      cycleDay: result.phase?.cycleDay,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---- hero: centered phase circle, focal element of the screen
        // A large circle filled with the phase colour, labelled in onPhase ink,
        // with the day number beneath it. For the unknown phase it is neutral
        // slate grey and says so, never implying a cycle state the data cannot
        // support. Cross-fades when the phase changes (ElaraAnimatedColor).
        const SizedBox(height: ElaraSpacing.xl),
        Center(
          child: _PhaseCircle(
            label: phaseLabel,
            cycleDay: result.phase?.cycleDay,
            fill: tokens.phaseFill(phaseKey),
          ),
        ),

        // ---- compact countdown: two facts on one line, no box around them
        const SizedBox(height: ElaraSpacing.xl),
        _Countdown(
          daysUntil: daysUntil,
          isLate: isLate,
          nextPeriodDate: result.nextPeriodDate,
          windowDays: result.windowDays,
          phaseKey: phaseKey,
          unavailableReason: result.unavailableReason,
        ),

        // ---- care: the point of the screen, given the most room.
        //
        // Two blocks, in order of how much the evidence actually tells you
        // about her: what she has said and reported (CareSuggestions), then
        // elara-core's phase prompt and food ideas (ActionCards). Both are part
        // of the same section; the hairline inside ActionCards is the only
        // divider, because stacking cards made every suggestion look equally
        // well founded.
        const SizedBox(height: ElaraSpacing.xl),
        ElaraSection(
          title: 'Ways to help today',
          children: [
            CareSuggestions(suggestions: suggestions, phaseKey: phaseKey),
            const SizedBox(height: ElaraSpacing.lg),
            ActionCards(
              action: result.action,
              phaseKey: phaseKey,
              unavailableReason: result.unavailableReason,
            ),
          ],
        ),

        // ---- her notes and the day's plans, between guidance and context
        const SizedBox(height: ElaraSpacing.lg),
        DayNotes(),

        // ---- climate, after the guidance: useful context, not the headline
        const SizedBox(height: ElaraSpacing.xl),
        ClimateStrip(snapshot: result.environment, phaseKey: phaseKey),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- lunar and calendars, last and quiet
        LunarStrip(date: now),
        const SizedBox(height: ElaraSpacing.md),
        Text(
          'Phase and period dates are estimates from recorded history, not a '
          'medical measurement. Traditional calendars are shown for '
          'information.',
          style: type.caption(tokens.textSecondaryStrong),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The phase circle: fill with phase colour, label in onPhase ink.
///
/// At 150 logical pixels it reads as a focal element without crowding the
/// countdown below it. The day number sits under the phase name in smaller
/// type, part of the same circle rather than repeated beneath it.
class _PhaseCircle extends StatelessWidget {
  const _PhaseCircle({
    required this.label,
    required this.cycleDay,
    required this.fill,
  });

  final String label;
  final int? cycleDay;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return ElaraAnimatedColor(
      color: fill,
      duration: ElaraMotion.medium,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(75),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Hind Siliguri',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                height: 1.2,
                color: tokens.onPhase,
              ),
            ),
            if (cycleDay != null) ...[
              const SizedBox(height: 4),
              Text(
                'Day $cycleDay',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hind Siliguri',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  height: 1.2,
                  color: tokens.onPhase.withValues(alpha: 0.85),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The next-period estimate, stated rather than displayed.
///
/// This used to be a card with a 60pt numeral, which made an estimate by a
/// statistical model the loudest thing on a screen about care. The information
/// is the same — days remaining, the date, the window, the cycle day — but it
/// now reads as a sentence with the number inline, and the numerals stay
/// tabular so they line up from day to day.
class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.daysUntil,
    required this.isLate,
    required this.nextPeriodDate,
    required this.windowDays,
    required this.phaseKey,
    required this.unavailableReason,
  });

  final int daysUntil;
  final bool isLate;
  final DateTime nextPeriodDate;
  final int windowDays;
  final String phaseKey;
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final numberColour =
        isLate ? tokens.warningText : tokens.phaseText(phaseKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ElaraSpacing.sm,
          runSpacing: ElaraSpacing.xxs,
          children: [
            ElaraOverline(
              isLate ? 'Estimated start has passed' : 'Next period in',
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // The days remaining are the one number on this screen that
                // changes because the user did something, so it counts to its
                // new value rather than jumping. The count-up is skipped when
                // the platform has asked for animations to be removed.
                ElaraCountUp(
                  value: daysUntil.abs().toDouble(),
                  builder: (context, value) => NumberText(
                    value.round().toString(),
                    style: type.number(numberColour, size: 24),
                  ),
                ),
                const SizedBox(width: ElaraSpacing.xs),
                Text(
                  isLate
                      ? (daysUntil.abs() == 1 ? 'day late' : 'days late')
                      : (daysUntil == 1 ? 'day' : 'days'),
                  style: type.label(tokens.textSecondaryStrong, size: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.xxs),
        Text(
          'Estimated ${_formatShortDate(nextPeriodDate)} '
          '\u00b1 $windowDays ${windowDays == 1 ? 'day' : 'days'}',
          style: type.caption(tokens.textSecondaryStrong),
        ),
        if (unavailableReason != null) ...[
          const SizedBox(height: ElaraSpacing.xxs),
          Text(
            unavailableReason!,
            style: type.caption(tokens.textSecondaryStrong),
          ),
        ],
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
