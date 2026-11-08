import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/food_chip_row.dart';

/// The guidance cards on Today.
///
/// Copy comes from elara-core's [core.ActionEngine]: the first card's `title` is
/// the phase-appropriate prompt ("Make time to connect", "Check in gently") and
/// its `body` is the standing caution that preferences can change. Nothing here
/// is scored.
///
/// Elara used to show a conversation score and a romance score as 0-10 bars.
/// They are gone on purpose: a number out of ten implies that a partner's
/// willingness to talk or be close can be measured, and that the calendar
/// predicts it. It cannot, and a bar that says 10/10 on a bad day does real
/// damage. The same information is here as words, which can carry a caveat.
class ActionCards extends StatelessWidget {
  const ActionCards({
    super.key,
    required this.action,
    required this.phaseKey,
    this.unavailableReason,
  });

  final core.ActionResult? action;
  final String phaseKey;
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final result = action;

    if (result == null) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No suggestions right now',
        message: unavailableReason ??
            'Suggestions appear once the current phase can be classified.',
      );
    }

    final prompt = result.cards.isNotEmpty ? result.cards.first : null;

    return Column(
      children: [
        ElaraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElaraOverline('A place to start', color: tokens.phaseText(phaseKey)),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                prompt?.title ??
                    'Ask how today actually feels before planning around it.',
                style: type.subtitle(tokens.textPrimary, size: 16),
              ),
              if (prompt != null) ...[
                const SizedBox(height: ElaraSpacing.sm),
                Text(prompt.body, style: type.body(tokens.textSecondaryStrong)),
              ],
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                'A suggestion, not a forecast. What she says matters more than '
                'what the calendar says.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.md),
        ElaraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElaraOverline('Food'),
              const SizedBox(height: ElaraSpacing.sm),
              FoodChipRow(
                foods: result.foodSuggestions,
                phaseKey: phaseKey,
              ),
              const SizedBox(height: ElaraSpacing.sm),
              Text(
                'Ideas to offer, not instructions for anyone\u2019s appetite.',
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
