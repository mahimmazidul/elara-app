import 'package:flutter/material.dart';

import '../data/food_notes.dart';
import '../theme/elara_theme.dart';

/// Suggested foods for the current phase, with what is actually in them.
///
/// These were outlined chips carrying a bare category — "Iron-rich foods" — which
/// is a nutrient, not a meal, and left the reader to work out the rest. Each one
/// is now a line with the category, what it supplies, and the things sold in a
/// Bangladeshi market that carry it. The name of the widget is older than the
/// change and is kept so the two call sites and the responsive test do not have
/// to churn for a rename.
///
/// A label this file has no note for renders as the label alone. A made-up
/// nutrient would be worse than a missing one.
class FoodChipRow extends StatelessWidget {
  const FoodChipRow({super.key, required this.foods, required this.phaseKey});

  final List<String> foods;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    if (foods.isEmpty) {
      return Text(
        'No food suggestions for this phase.',
        style: type.caption(tokens.textSecondaryStrong),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < foods.length; i++) ...[
          if (i > 0) const SizedBox(height: ElaraSpacing.md),
          _FoodLine(
            label: foods[i],
            note: foodNoteFor(foods[i]),
            phaseKey: phaseKey,
          ),
        ],
      ],
    );
  }
}

class _FoodLine extends StatelessWidget {
  const _FoodLine({
    required this.label,
    required this.note,
    required this.phaseKey,
  });

  final String label;
  final FoodNote? note;
  final String phaseKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A dot in the phase colour rather than an icon: the food list is not a
        // list of warnings, and the glyph vocabulary has no food mark that is
        // not a fork.
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tokens.phaseFill(phaseKey),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: ElaraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: type.label(tokens.textPrimary, size: 14)),
              if (note != null) ...[
                const SizedBox(height: 1),
                Text(
                  note!.nutrient,
                  style: type
                      .caption(tokens.phaseText(phaseKey), size: 12)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: ElaraSpacing.xxs),
                Text(
                  note!.examples,
                  style: type.caption(tokens.textSecondaryStrong, size: 13),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
