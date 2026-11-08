import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';

/// Suggested foods for the current phase, as outlined chips.
///
/// Moved here from score_bar.dart when the score bars were removed: the chips
/// are a keeper, the numbers were not.
///
/// Each chip's border uses the phase colour, and the label uses the text-safe
/// primary ink, so the row reads as one object per suggestion rather than
/// competing with the card behind it.
class FoodChipRow extends StatelessWidget {
  const FoodChipRow({
    super.key,
    required this.foods,
    required this.phaseKey,
  });

  final List<String> foods;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    if (foods.isEmpty) {
      return Text(
        'No food suggestions for this phase.',
        style: context.type.caption(tokens.textSecondaryStrong),
      );
    }
    return Wrap(
      spacing: ElaraSpacing.sm,
      runSpacing: ElaraSpacing.sm,
      children: [
        for (final food in foods)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ElaraSpacing.md,
              vertical: ElaraSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: tokens.bgCard,
              borderRadius: BorderRadius.circular(ElaraRadii.chip),
              border: Border.all(color: tokens.phaseFill(phaseKey), width: 1),
            ),
            child: Text(
              food,
              style: context.type.label(tokens.textPrimary),
            ),
          ),
      ],
    );
  }
}
