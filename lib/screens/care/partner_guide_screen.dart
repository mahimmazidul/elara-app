import 'package:material_ui/material_ui.dart';

import '../../data/partner_phases.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';

/// The full partner guide, opened from the phase estimate on Today.
///
/// When a phase is known, the guide begins with that card and then continues
/// around the cycle. Without a current estimate it keeps the usual cycle order.
class PartnerGuideScreen extends StatelessWidget {
  const PartnerGuideScreen({super.key, this.currentPhaseKey});

  final String? currentPhaseKey;

  static Route<void> route(
    BuildContext context, {
    String? currentPhaseKey,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => PartnerGuideScreen(currentPhaseKey: currentPhaseKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final phases = _phasesFrom(currentPhaseKey);
    final hasCurrentPhase = phases.any(
      (phase) => phase.phaseKey == currentPhaseKey,
    );

    return ElaraSubPage(
      title: 'What helps, by phase',
      children: [
        Text(
          hasCurrentPhase
              ? 'The phase Elara estimated for today comes first. Dates can help '
                    'you think ahead; they cannot tell you how she feels. Ask '
                    'her, take the answer seriously, and let the calendar stay '
                    'in its place.'
              : 'Dates can suggest a phase, not tell you how she feels. These '
                    'notes describe common body changes and offer ideas, not a '
                    'script. Ask her, take the answer seriously, and let the '
                    'calendar stay in its place.',
          style: type.body(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.lg),
        for (final phase in phases) ...[
          _PhaseCard(
            phase: phase,
            isCurrent: hasCurrentPhase && phase.phaseKey == currentPhaseKey,
          ),
          const SizedBox(height: ElaraSpacing.lg),
        ],
        Text(
          'The body notes draw on general NHS and ACOG guidance. Practical '
          'ideas echo recurring themes in posts on r/AskWomen and '
          'r/AskWomenOver30: warmth, a meal, one less chore, or room to be '
          'alone. Those are personal accounts, not medical evidence, and they '
          'disagree. Her answer comes first.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }

  List<PartnerPhase> _phasesFrom(String? phaseKey) {
    final index = partnerPhases.indexWhere(
      (phase) => phase.phaseKey == phaseKey,
    );
    if (index <= 0) return partnerPhases;
    return [...partnerPhases.skip(index), ...partnerPhases.take(index)];
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase, required this.isCurrent});

  final PartnerPhase phase;
  final bool isCurrent;

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
              // A dot ties the card to the phase on Today without tinting its
              // surface or introducing another colour.
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              ),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: Text(
                  phase.timing.toUpperCase(),
                  style: type.label(tokens.textSecondaryStrong),
                ),
              ),
            ],
          ),
          if (isCurrent) ...[
            const SizedBox(height: ElaraSpacing.xs),
            Text(
              'ESTIMATED FOR TODAY',
              style: type.caption(tokens.textSecondaryStrong, size: 11),
            ),
          ],
          const SizedBox(height: ElaraSpacing.xs),
          Text(phase.name, style: type.headline(tokens.textPrimary, size: 22)),
          const SizedBox(height: 2),
          Text(phase.aka, style: type.caption(text)),
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
            'From the kitchen, if she wants',
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
/// The marker is text rather than an icon: a tick and a dot read at a glance,
/// and neither becomes a red cross beside a line about someone's body.
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
                  child: Text(marker, style: type.body(markerColour)),
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
