import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/elara_result.dart';
import '../../providers/climate_provider.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../services/care_recommender.dart';
import '../../theme/elara_theme.dart';
import '../../utils/history_quality.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/motion.dart';
import '../../widgets/phase_dial.dart';
import '../../widgets/primitives.dart';
import 'action_cards.dart';
import 'care_suggestions.dart';
import 'day_notes.dart';
import 'climate_strip.dart';
import 'lunar_strip.dart';
import 'onboarding_card.dart';
import 'quiet_today.dart';
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

    // A mode that is not predicting takes precedence over everything below,
    // including onboarding: someone on the pill who has logged nothing yet
    // should be told why Elara is quiet, not asked for a period start it is
    // not going to use.
    if (!context.watch<SettingsProvider>().cycleMode.predicts) {
      return const QuietToday();
    }

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
        message:
            prediction.lastError ??
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
                Icon(
                  ElaraIcons.recorded,
                  size: 18,
                  color: tokens.textSecondaryStrong,
                ),
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

    // What the history itself implies about the estimate below it. Computed
    // from the recorded starts and the returned window, and shown under the
    // date rather than folded into it: a note is not a prediction.
    final historyNotes = HistoryQuality.notesFor(
      starts: context
          .watch<CycleProvider>()
          .cycles
          .map((entry) => entry.startDate)
          .toList(growable: false),
      windowDays: result.windowDays,
    );

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
            ],
          ),
        ),

        // ---- hero: the cycle dial, focal element of the screen.
        //
        // Where today sits in the cycle, as a ring: the sweep is the cycle, the
        // gap is what is left of it, the dot is today, and the moon inside it
        // is the cycle's moon rather than the sky's. With no phase the ring is
        // neutral and has no sweep at all, rather than sitting at 0%.
        const SizedBox(height: ElaraSpacing.xl),
        Center(
          child: PhaseDial(
            label: phaseLabel,
            phaseKey: phaseKey,
            cycleDay: result.phase?.cycleDay,
            cycleLength: result.cycleLength,
            fill: tokens.phaseFill(phaseKey),
          ),
        ),

        // The chip that used to sit here repeated the dial's own label one line
        // above it. The thing worth keeping from it was not the phase name but
        // the word "estimate", so that is what stays — once, under the dial.
        const SizedBox(height: ElaraSpacing.sm),
        Text(
          'Estimated phase, from recorded history',
          textAlign: TextAlign.center,
          style: type.caption(tokens.textSecondaryStrong, size: 12),
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
          historyNotes: historyNotes,
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
    this.historyNotes = const [],
  });

  final int daysUntil;
  final bool isLate;
  final DateTime nextPeriodDate;
  final int windowDays;
  final String phaseKey;
  final String? unavailableReason;
  final List<HistoryNote> historyNotes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final numberColour = isLate
        ? tokens.warningText
        : tokens.phaseText(phaseKey);

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
        // Notes about the history behind the date, set apart with a hairline so
        // they read as a remark about the estimate rather than as part of it.
        if (historyNotes.isNotEmpty) ...[
          const SizedBox(height: ElaraSpacing.sm),
          Container(height: 1, width: 40, color: tokens.divider),
          const SizedBox(height: ElaraSpacing.sm),
          for (final note in historyNotes) ...[
            Text(note.message, style: type.caption(tokens.textSecondaryStrong)),
            const SizedBox(height: ElaraSpacing.xs),
          ],
        ],
      ],
    );
  }
}

const List<String> _months = [
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

String _formatLongDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String _formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1].substring(0, 3)} ${date.year}';
