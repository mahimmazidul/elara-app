import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';
import 'primitives.dart';

/// A 1-10 score as a horizontal bar filled in the phase colour.
///
/// The bar is a rounded track with a filled portion whose width is the score's
/// fraction of [max]. The numeric value sits beside it in tabular figures so the
/// two presentations agree at a glance.
///
/// Accessibility: the track/fill pair is decorative and the number carries the
/// value, so the fill has a [Semantics] label rather than relying on colour.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.score,
    required this.phaseKey,
    this.max = 10,
    this.label,
    this.guidance,
  });

  final int score;
  final String phaseKey;
  final int max;

  /// e.g. "Conversation".
  final String? label;

  /// One sentence of guidance shown under the bar.
  final String? guidance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final clamped = score.clamp(0, max);
    final fraction = max == 0 ? 0.0 : clamped / max;
    final fill = tokens.phaseFill(phaseKey);

    return Semantics(
      label: '${label ?? 'Score'} $clamped out of $max',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            ElaraOverline(label!, color: tokens.textSecondaryStrong),
            const SizedBox(height: ElaraSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ElaraRadii.bar),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        // Track.
                        Positioned.fill(
                          child: ColoredBox(color: tokens.track),
                        ),
                        // Fill.
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fraction,
                            child: ColoredBox(color: fill),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ElaraSpacing.md),
              NumberText(
                '$clamped',
                size: 16,
                color: tokens.phaseText(phaseKey),
                suffix: '/$max',
              ),
            ],
          ),
          if (guidance != null) ...[
            const SizedBox(height: ElaraSpacing.sm),
            Text(
              guidance!,
              style: context.type.body(tokens.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

/// A wrapping row of food suggestions, each a chip in the card colour with a
/// thin phase-coloured border.
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
