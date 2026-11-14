import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/partner_phases.dart';
import '../../models/elara_result.dart';
import '../../providers/climate_provider.dart';
import '../../providers/cycle_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../services/care_recommender.dart';
import '../care/partner_guide_screen.dart';
import '../../theme/elara_theme.dart';
import '../../utils/history_quality.dart';
import '../../utils/phase_timeline.dart';
import '../../widgets/motion.dart';
import '../../widgets/phase_dial.dart';
import '../../widgets/primitives.dart';
import '../../providers/reminders_provider.dart';
import '../../utils/moon_phase.dart';
import '../../widgets/icons.dart';
import 'action_cards.dart';
import 'calendars_page.dart';
import 'care_suggestions.dart';
import 'notes_page.dart';
import 'onboarding_card.dart';
import 'quiet_today.dart';
import 'weather_page.dart';

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
        const SizedBox(height: ElaraSpacing.md),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            PartnerGuideScreen.route(context),
          ),
          icon: const Icon(ElaraIcons.care),
          label: const Text('Read the phase guide'),
        ),
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
    final recommender = const CareRecommender();
    final suggestions = recommender.recommend(
      preferences: preferences.all,
      recentSymptoms: symptoms.recent,
      climate: result.environment,
      today: now,
    );
    // The general layer is labelled with its source and shown underneath hers,
    // or on its own when there is nothing personal yet.
    final general = recommender.generalFor(phaseKey);
    final activePhaseGuide = partnerPhaseFor(phaseKey);

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

        // ---- phase and estimate, kept on the page rather than inside a
        // saturated panel. The dial still uses the phase accent, while the
        // estimate and guidance share the same readable paper surface.
        const SizedBox(height: ElaraSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElaraOverline('Estimated phase'),
            const SizedBox(height: ElaraSpacing.xxs),
            Text(
              'From the dates you have recorded',
              style: type.caption(tokens.textSecondaryStrong, size: 12),
            ),
            const SizedBox(height: ElaraSpacing.md),
            // Where today sits in the cycle, as a ring of one tick per day:
            // the elapsed ticks carry the ink, the dot is today, and the moon
            // inside is the cycle's moon rather than the sky's.
            Center(
              child: PhaseDial(
                label: phaseLabel,
                phaseKey: phaseKey,
                cycleDay: result.phase?.cycleDay,
                cycleLength: result.cycleLength,
                fill: tokens.phaseFill(phaseKey),
              ),
            ),
            const SizedBox(height: ElaraSpacing.lg),
            const Hairline(margin: 0),
            const SizedBox(height: ElaraSpacing.lg),
            _Countdown(
              daysUntil: daysUntil,
              isLate: isLate,
              nextPeriodDate: result.nextPeriodDate,
              windowDays: result.windowDays,
              phaseKey: phaseKey,
              unavailableReason: result.unavailableReason,
              historyNotes: historyNotes,
            ),
          ],
        ),
        if (activePhaseGuide != null) ...[
          const SizedBox(height: ElaraSpacing.lg),
          PhaseGuideCard(
            phase: activePhaseGuide,
            isCurrent: true,
          ),
        ],

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
            const SizedBox(height: ElaraSpacing.xxl),
            ActionCards(
              action: result.action,
              phaseKey: phaseKey,
              general: general,
              unavailableReason: result.unavailableReason,
            ),
          ],
        ),

        // ---- the rest of the day, one tap away.
        //
        // These three used to be the bottom half of this scroll: the day's
        // notes, the weather, the moon and the calendars. All worth having, none
        // of them worth scrolling past to reach. As rows with a line each, the
        // reader can see what is behind them and decide — which is what the
        // settings hub does, and it works for the same reason here.
        const SizedBox(height: ElaraSpacing.xl),
        const _GroupLabel('More about today'),
        ElaraGlassGroup(
          children: [
            ElaraListRow(
              title: 'Notes and plans',
              subtitle: _notesSummary(context),
              icon: ElaraIcons.symptom,
              onTap: () => Navigator.of(context).push(NotesPage.route(context)),
            ),
            ElaraListRow(
              title: 'Weather and air',
              subtitle: _weatherSummary(result),
              icon: ElaraIcons.weather,
              onTap: () =>
                  Navigator.of(context).push(WeatherPage.route(context)),
            ),
            ElaraListRow(
              title: 'Moon and calendars',
              subtitle: _calendarsSummary(now),
              icon: ElaraIcons.moon,
              onTap: () =>
                  Navigator.of(context).push(CalendarsPage.route(context)),
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.xl),

        // ---- the standing caveat, last and quiet
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
/// is the same: days remaining, the date, the window, the cycle day. It now
/// reads as a sentence with the number inline, and the numerals stay tabular so
/// they line up from day to day.
class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.daysUntil,
    required this.isLate,
    required this.nextPeriodDate,
    required this.windowDays,
    required this.phaseKey,
    required this.unavailableReason,
    this.historyNotes = const [],
    this.onHero = false,
  });

  final int daysUntil;
  final bool isLate;
  final DateTime nextPeriodDate;
  final int windowDays;
  final String phaseKey;
  final String? unavailableReason;
  final List<HistoryNote> historyNotes;

  /// Whether the countdown is drawn inside the hero panel.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    // On the panel the ink is the panel's ink: the phase's own text colour is
    // tuned for a paper background and would either vanish or clash here.
    final muted = onHero
        ? tokens.onHero.withValues(alpha: 0.78)
        : tokens.textSecondaryStrong;
    final numberColour = onHero
        ? tokens.onHero
        : (isLate ? tokens.warningText : tokens.phaseText(phaseKey));

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
              color: muted,
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
                  style: type.label(muted, size: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.xxs),
        Text(
          'Estimated ${_formatShortDate(nextPeriodDate)} '
          '\u00b1 $windowDays ${windowDays == 1 ? 'day' : 'days'}',
          style: type.caption(muted),
        ),
        if (unavailableReason != null) ...[
          const SizedBox(height: ElaraSpacing.xxs),
          Text(unavailableReason!, style: type.caption(muted)),
        ],
        // Notes about the history behind the date, set apart with a hairline so
        // they read as a remark about the estimate rather than as part of it.
        if (historyNotes.isNotEmpty) ...[
          const SizedBox(height: ElaraSpacing.sm),
          Container(
            height: 1,
            width: 40,
            color: onHero
                ? tokens.onHero.withValues(alpha: 0.18)
                : tokens.divider,
          ),
          const SizedBox(height: ElaraSpacing.sm),
          for (final note in historyNotes) ...[
            Text(note.message, style: type.caption(muted)),
            const SizedBox(height: ElaraSpacing.xs),
          ],
        ],
      ],
    );
  }
}

/// The one line on the notes row: what is actually waiting behind it.
String _notesSummary(BuildContext context) {
  final recent = context.watch<SymptomsProvider>().recent;
  final planned = context.watch<RemindersProvider>().upcoming(days: 1);
  if (recent.isEmpty && planned.isEmpty) return 'Nothing noted today';
  final parts = <String>[
    if (recent.isNotEmpty)
      recent.length == 1 ? '1 symptom' : '${recent.length} symptoms',
    if (planned.isNotEmpty)
      planned.length == 1 ? '1 plan' : '${planned.length} plans',
  ];
  return parts.join(' · ');
}

/// The weather row: the number if there is one, and the truth if there is not.
String _weatherSummary(ElaraResult result) {
  final snapshot = result.environment;
  final heat = snapshot.heatIndex.toStringAsFixed(0);
  final source = snapshot.isFallback ? 'seasonal estimate' : 'heat index';
  return '$heat\u00b0C $source · PM2.5 ${snapshot.pm25.toStringAsFixed(0)}';
}

/// The calendars row: the moon phase, which is the one value people look at.
String _calendarsSummary(DateTime now) {
  final moon = MoonPhase.forDate(now);
  return '${moon.name} · ${moon.illuminationLabel}';
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
