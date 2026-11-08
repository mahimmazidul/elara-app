import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/score_bar.dart';

/// The three guidance cards on Today.
///
/// Content comes from elara-core's [core.ActionEngine], which returns a
/// conversation score, a romance score, food suggestions and two cards. The
/// mapping used here, so no copy is invented in the UI:
///
///   * Conversation guidance = the first card's `title`, which is the
///     phase-specific prompt ("Make time to connect", "Check in gently", ...).
///   * Romance guidance = the first card's `body`, the standing caution that
///     preferences can change ("Ask what would feel welcome").
///   * Food chips = `foodSuggestions`.
///
/// If the action engine declined (unknown phase), the cards are not guessed at;
/// a short explanation is shown instead.
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

    final promptTitle =
        result.cards.isNotEmpty ? result.cards.first.title : null;
    final promptBody = result.cards.isNotEmpty ? result.cards.first.body : null;

    return Column(
      children: [
        ElaraCard(
          child: ScoreBar(
            label: 'Conversation',
            score: result.conversationScore,
            phaseKey: phaseKey,
            guidance: promptTitle,
          ),
        ),
        const SizedBox(height: ElaraSpacing.md),
        ElaraCard(
          child: ScoreBar(
            label: 'Romance',
            score: result.romanceScore,
            phaseKey: phaseKey,
            guidance: promptBody,
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
