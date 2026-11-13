import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models/cycle_mode.dart';
import '../../providers/climate_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/symptoms_provider.dart';
import '../../services/care_recommender.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';
import '../care/partner_guide_screen.dart';
import 'care_suggestions.dart';
import 'climate_strip.dart';
import 'day_notes.dart';
import 'lunar_strip.dart';

/// Today, when Elara is not predicting.
///
/// This screen is not an error state and must not look like one. Something
/// has changed in her life — a method of contraception, a pregnancy, a loss, or
/// a decision that this app should stop counting days — and the correct
/// response is to stop making a claim, say so once, and keep being useful.
///
/// What stays: her logged bleeding, her symptoms, his notes, the care
/// suggestions built from what she has said, the reminders, the weather. What
/// goes: the phase, the countdown, the window, the fertile estimate, and every
/// scheduled reminder that depends on them. Care is not prediction, and only
/// one of the two has been withdrawn.
class QuietToday extends StatelessWidget {
  const QuietToday({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final settings = context.watch<SettingsProvider>();
    final preferences = context.watch<PreferencesProvider>();
    final symptoms = context.watch<SymptomsProvider>();
    final climate = context.watch<ClimateProvider>().snapshot;
    final mode = settings.cycleMode;

    final suggestions = const CareRecommender().recommend(
      preferences: preferences.all,
      recentSymptoms: symptoms.recent,
      climate: climate,
      today: DateTime.now(),
    );

    return ListView(
      padding: ElaraSpacing.pageInsets(context),
      children: [
        Text('Today', style: type.headline(tokens.textPrimary, size: 28)),
        const SizedBox(height: ElaraSpacing.xxs),
        Text(
          _formatLongDate(DateTime.now()),
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.xl),

        _ModePanel(
          mode: mode,
          reason: settings.pauseReason,
          since: settings.pauseSince,
        ),

        const SizedBox(height: ElaraSpacing.xl),
        ElaraSection(
          title: 'Ways to help today',
          children: [
            CareSuggestions(suggestions: suggestions, phaseKey: 'unknown'),
            const SizedBox(height: ElaraSpacing.lg),
            Text(
              // The guidance below is not phase-derived here, and says so. The
              // moment this screen implies "because it is her luteal phase",
              // it is claiming a cycle it has just said it cannot see.
              'These come from what she has told you, what she has reported, '
              'and the weather. Where a phase would normally decide what to '
              'say, the app skips that part here.',
              style: type.caption(tokens.textSecondaryStrong),
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.xs),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            PartnerGuideScreen.route(context),
          ),
          icon: const Icon(ElaraIcons.care),
          label: const Text('Read the phase guide'),
        ),

        const SizedBox(height: ElaraSpacing.lg),
        const DayNotes(),

        if (climate != null) ...[
          const SizedBox(height: ElaraSpacing.xl),
          ClimateStrip(snapshot: climate, phaseKey: 'unknown'),
        ],

        const SizedBox(height: ElaraSpacing.xl),
        LunarStrip(date: DateTime.now()),
        const SizedBox(height: ElaraSpacing.md),
        Text(
          'Bleeding you log here is kept either way, and it is still there '
          'when a prediction resumes.',
          style: type.caption(tokens.textSecondaryStrong),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ModePanel extends StatelessWidget {
  const _ModePanel({
    required this.mode,
    required this.reason,
    required this.since,
  });

  final CycleMode mode;
  final PauseReason? reason;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    final copy = _copyFor(mode, reason);

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ElaraIcons.info,
                size: 18,
                color: tokens.textSecondaryStrong,
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: Text(
                  copy.title,
                  style: type.title(tokens.textPrimary, size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.sm),
          for (final paragraph in copy.paragraphs) ...[
            Text(paragraph, style: type.body(tokens.textSecondaryStrong)),
            const SizedBox(height: ElaraSpacing.sm),
          ],
          if (since != null && mode != CycleMode.predicting)
            Text(
              'Quiet since ${_formatShortDate(since!)}.',
              style: type.caption(tokens.textSecondaryStrong),
            ),
          const SizedBox(height: ElaraSpacing.md),
          Wrap(
            spacing: ElaraSpacing.sm,
            runSpacing: ElaraSpacing.sm,
            children: [
              OutlinedButton(
                // Not a dismiss. Turning prediction back on is the only way
                // out of this screen, and it lives here as well as in Settings
                // because this is where the user notices the app is quiet.
                onPressed: () => _resume(context),
                child: const Text('Start predicting again'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resume(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final ok = await settings.setCycleMode(CycleMode.predicting);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.lastError ?? 'Could not change that setting.'),
        ),
      );
    }
  }
}

/// The words.
///
/// Written for a person, not a persona: short sentences, no "cycle health
/// journey", no exclamation mark, and not one line that tells someone what is
/// happening in her body. Every paragraph answers one question — why is the app
/// quiet, is my data gone, and can I undo this — because those are the three
/// things a person asks when an app stops doing its main job.
({String title, List<String> paragraphs}) _copyFor(
  CycleMode mode,
  PauseReason? reason,
) {
  switch (mode) {
    case CycleMode.predicting:
      // Unreachable: Today only renders this screen when not predicting.
      return (title: 'Elara is predicting', paragraphs: const []);

    case CycleMode.hormonalContraception:
      return (
        title: 'The forecast is paused while she is on hormonal contraception',
        paragraphs: const [
          'Pills, implants, injections and most hormonal IUDs stop ovulation. '
              'The bleeding they cause is not the end of a cycle, so a date worked '
              'out from those days would be a guess about something that is not '
              'happening.',
          'Everything else still works. Log the days she bleeds, log how she '
              'feels, keep your notes, keep the reminders.',
        ],
      );

    case CycleMode.paused:
      switch (reason) {
        case PauseReason.pregnancy:
          return (
            title: 'Prediction paused',
            paragraphs: const [
              'A pregnancy is not a cycle, and counting days through one would '
                  'be nonsense dressed as arithmetic.',
              'Her history is still here. Anything you log now is kept, and '
                  'prediction can start again whenever it is useful.',
            ],
          );
        case PauseReason.loss:
          return (
            title: 'Prediction paused',
            paragraphs: const [
              'Nothing here is counting days. Bleeding after a loss does not '
                  'follow the pattern of a cycle, and a countdown would be both '
                  'wrong and unkind.',
              'The first period after a loss can take weeks to arrive. That is '
                  'not a late period, so Elara will not call it one.',
            ],
          );
        case PauseReason.postpartum:
          return (
            title: 'Prediction paused',
            paragraphs: const [
              'After a birth, cycles take time to return. Often months, and '
                  'later still while breastfeeding. There is no schedule to '
                  'estimate from until one exists again.',
              'Her history is kept. Log bleeding whenever it comes back, and '
                  'turn prediction on when it does.',
            ],
          );
        case PauseReason.other:
        case null:
          return (
            title: 'Prediction paused',
            paragraphs: const [
              'Elara is not estimating a next period. You chose this, and it '
                  'can be undone at any time.',
              'Her history is kept, and logging still works.',
            ],
          );
      }
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
