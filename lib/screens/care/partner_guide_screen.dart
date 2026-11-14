import 'package:material_ui/material_ui.dart';

import '../../data/partner_phases.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';

/// The partner phase guide.
///
/// On the Today tab, the suitable [PhaseGuideCard] for the active phase is
/// rendered directly inline after the hero estimate. When opened as a sub-page
/// (for example before any cycle is recorded), it lets the reader view one
/// phase at a time or browse the cycle with natural, conversational notes.
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
                    'you plan ahead, while her own words always tell you how '
                    'she actually feels.'
              : 'Dates can suggest a phase of the cycle, while her own words '
                    'tell you how she feels. Use these notes for practical '
                    'household and kitchen ideas.',
          style: type.body(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.lg),
        for (final phase in phases) ...[
          PhaseGuideCard(
            phase: phase,
            isCurrent: hasCurrentPhase && phase.phaseKey == currentPhaseKey,
          ),
          const SizedBox(height: ElaraSpacing.lg),
        ],
        Text(
          'Body notes draw on general NHS and ACOG guidance alongside '
          'everyday household and Bangladeshi kitchen ideas. Every person '
          'experiences her cycle differently, so her answer always comes first.',
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

/// Renders the practical partner guide for a single [PartnerPhase].
///
/// Shown directly on the Today tab for the currently active phase so the user
/// sees the relevant phase guidance right below the period estimate instead of
/// opening a separate multi-phase page.
class PhaseGuideCard extends StatelessWidget {
  const PhaseGuideCard({
    super.key,
    required this.phase,
    this.isCurrent = false,
  });

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
          Text(phase.name, style: type.title(tokens.textPrimary, size: 19)),
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
            marker: ElaraIcons.confirmed,
            markerColour: tokens.successText,
          ),
          const SizedBox(height: ElaraSpacing.md),
          _ListBlock(
            title: 'Skip',
            items: phase.skip,
            marker: ElaraIcons.unselected,
            markerColour: tokens.textSecondaryStrong,
          ),
          const SizedBox(height: ElaraSpacing.md),
          const Hairline(margin: ElaraSpacing.md),
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

class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.title,
    required this.items,
    required this.marker,
    required this.markerColour,
  });

  final String title;
  final List<String> items;
  final IconData marker;
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
                  child: Icon(
                    marker,
                    size: 16,
                    color: markerColour,
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
