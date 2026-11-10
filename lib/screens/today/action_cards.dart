import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../widgets/food_chip_row.dart';
import '../../widgets/icons.dart';
import '../../widgets/primitives.dart';

/// The action card on Today: elara-core's phase prompt, and the foods that go
/// with it.
///
/// Copy comes from [core.ActionEngine] via [core.ActionResult.cards]. The first
/// card's `title` is the phase-appropriate prompt ("Make time to connect",
/// "Check in gently") and its `body` is the standing caution that preferences
/// can change. `foodSuggestions` is a short list of foods to offer.
///
/// **What this widget deliberately does not show.** [core.ActionResult] also
/// carries `conversationScore` and `romanceScore`. Elara used to draw them as
/// 0-10 bars and no longer does: a number out of ten implies that a partner's
/// willingness to talk or be close can be measured, and that a calendar predicts
/// it. It cannot, and a bar reading 10/10 on a bad day does real damage. The
/// scores remain unwired here on purpose; the same information is carried by
/// words, which can hold a caveat.
///
/// **Layout.** This used to be two stacked [ElaraCard]s inside an already
/// card-heavy screen — a box, inside a section, above another box. It is now one
/// block separated by a hairline, with the phase colour used as an accent on the
/// overline and the chip borders rather than as a background wash. Same content,
/// one less container.
///
/// This block sits *after* the evidence-based suggestions in
/// [CareSuggestions] because everything here is derived from an estimated
/// cycle phase, which is the weakest evidence the app has about her.
class ActionCards extends StatelessWidget {
  const ActionCards({
    super.key,
    required this.action,
    required this.phaseKey,
    this.unavailableReason,
  });

  /// The phase-derived action, or null when the phase cannot be classified.
  final core.ActionResult? action;
  final String phaseKey;

  /// Shown when [action] is null, explaining why rather than leaving a gap.
  final String? unavailableReason;

  /// Cards after the first that add information of their own.
  List<core.ActionCard> _extraCards(core.ActionResult result) {
    final foods = result.foodSuggestions.join(', ').toLowerCase();
    return result.cards.skip(1).where((card) {
      final body = card.body.toLowerCase().trim();
      final title = card.title.toLowerCase().trim();
      // "Food idea — Complex carbohydrates, Iron-rich foods" duplicates the chip
      // row, whether it repeats the whole list or just one entry; anything else
      // is information the block does not already carry, so it is shown.
      if (title == 'food idea') return false;
      if (body.isEmpty) return false;
      return !foods.contains(body);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final result = action;
    final accent = tokens.phaseText(phaseKey);

    // A hairline above, not a box around: the block belongs to the section
    // above it rather than starting a new surface.
    return Container(
      padding: const EdgeInsets.only(top: ElaraSpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ElaraIcons.care, size: ElaraIcons.size, color: accent),
              const SizedBox(width: ElaraSpacing.xs),
              Expanded(
                child: ElaraOverline('From the estimated phase', color: accent),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.sm),

          if (result == null) ...[
            Text(
              unavailableReason ??
                  'Phase guidance appears once the current phase can be '
                      'estimated from recorded history.',
              style: type.body(tokens.textSecondaryStrong),
            ),
          ] else ...[
            Text(
              result.cards.isNotEmpty
                  ? result.cards.first.title
                  : 'Ask how today actually feels before planning around it.',
              style: type.subtitle(tokens.textPrimary, size: 16),
            ),
            if (result.cards.isNotEmpty) ...[
              const SizedBox(height: ElaraSpacing.xs),
              Text(
                result.cards.first.body,
                style: type.body(tokens.textSecondaryStrong),
              ),
            ],

            // Any further cards the engine returns are rendered rather than
            // dropped. Today's engine sends one prompt plus a "Food idea" card
            // that only restates the chips below, so that one is skipped; the
            // rule is that a card is shown when it says something the block does
            // not already say.
            ..._extraCards(result).map(
              (card) => Padding(
                padding: const EdgeInsets.only(top: ElaraSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: type.label(tokens.textPrimary),
                    ),
                    const SizedBox(height: ElaraSpacing.xxs),
                    Text(
                      card.body,
                      style: type.body(tokens.textSecondaryStrong),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ElaraSpacing.md),

            // ---- food
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

          const SizedBox(height: ElaraSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  ElaraIcons.observation,
                  size: 14,
                  color: tokens.textSecondaryStrong,
                ),
              ),
              const SizedBox(width: ElaraSpacing.xs),
              Expanded(
                child: Text(
                  'A suggestion, not a forecast. What she says matters more '
                  'than what the calendar says.',
                  style: type.caption(tokens.textSecondaryStrong),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
