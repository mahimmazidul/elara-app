import 'package:material_ui/material_ui.dart';

import '../../data/partner_phases.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';

/// The four phases, and what to do with each one.
///
/// Elara is written for the person standing next to her: the app says "she", the
/// care suggestions are things someone else can do, and the phase card on Today
/// is the fact the rest of the advice hangs on. What the app did not have was one
/// place to read all of it at once - the suggestions are for today, the food
/// notes are per phase and per screen, and none of it answers "what is this week
/// going to be like, and what can I do about it".
///
/// Every phase is an estimate built from dates she recorded, so the screen says
/// that at the top and does not repeat the caveat four times.
class PartnerGuideScreen extends StatelessWidget {
  const PartnerGuideScreen({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const PartnerGuideScreen());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return ElaraSubPage(
      title: 'What helps, by phase',
      children: [
        Text(
          'The phase comes from the dates she recorded, so treat it as the '
          'weather forecast and not as a reading. What she says about how she '
          'feels beats anything on this page.',
          style: type.body(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.lg),
        for (final phase in partnerPhases) ...[
          _PhaseCard(phase: phase),
          const SizedBox(height: ElaraSpacing.lg),
        ],
        Text(
          'Food here is ordinary food from the local market, and none of it is a '
          'treatment. For pain that stops her day, bleeding that soaks through, '
          'or anything that worries either of you, a clinician is the next stop '
          'rather than this screen.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase});

  final PartnerPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final fill = tokens.phaseFill(phase.phaseKey);
    final text = tokens.phaseText(phase.phaseKey);

    return ElaraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A dot of the phase's own colour ties the card to the calendar
              // and the hero panel above it without tinting the whole card.
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: Text(
                  phase.days.toUpperCase(),
                  style: type.label(tokens.textSecondaryStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.xs),
          Text(phase.name, style: type.headline(tokens.textPrimary, size: 22)),
          const SizedBox(height: 2),
          Text(
            phase.aka,
            style: type.caption(text),
          ),
          const SizedBox(height: ElaraSpacing.sm),
          Text(
            phase.whatHappens,
            style: type.body(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.md),
          _ListBlock(
            title: 'Do',
            items: phase.doThis,
            marker: '✓',
            markerColour: tokens.successText,
          ),
          const SizedBox(height: ElaraSpacing.md),
          _ListBlock(
            title: 'Skip',
            items: phase.skip,
            marker: '·',
            markerColour: tokens.textSecondaryStrong,
          ),
          const SizedBox(height: ElaraSpacing.md),
          const Hairline(),
          const SizedBox(height: ElaraSpacing.md),
          Text(
            'In the kitchen',
            style: type.label(tokens.textSecondaryStrong),
          ),
          const SizedBox(height: ElaraSpacing.xs),
          for (final food in phase.foods)
            Padding(
              padding: const EdgeInsets.only(bottom: ElaraSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: type.subtitle(tokens.textPrimary, size: 15),
                  ),
                  Text(
                    food.why,
                    style: type.caption(tokens.textSecondaryStrong),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled list with a marker in the gutter.
///
/// The marker is text rather than an icon: a tick and a dash read at a glance
/// and neither of them is a red cross, which is the last thing a guide about
/// someone's body should put next to a line of advice.
class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.title,
    required this.items,
    required this.marker,
    required this.markerColour,
  });

  final String title;
  final List<String> items;
  final String marker;
  final Color markerColour;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: type.label(tokens.textSecondaryStrong)),
        const SizedBox(height: ElaraSpacing.xs),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: ElaraSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    marker,
                    style: type.body(markerColour),
                  ),
                ),
                Expanded(
                  child: Text(item, style: type.body(tokens.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
