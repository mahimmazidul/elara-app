import 'package:flutter/material.dart';

import '../theme/elara_theme.dart';

/// The large phase chip on the Today screen.
///
/// Filled with the phase colour and labelled in [ElaraTokens.onPhase], which is
/// the one ink that clears AA against all four fills (measured 5.2-9.1:1 in
/// light mode, 5.7-10.0:1 in dark).
class PhaseChip extends StatelessWidget {
  const PhaseChip({
    super.key,
    required this.label,
    required this.phaseKey,
    this.cycleDay,
    this.compact = false,
  });

  final String label;

  /// One of `menstrual`, `follicular`, `ovulatory`, `luteal`, `unknown`.
  final String phaseKey;
  final int? cycleDay;

  /// Smaller variant for the calendar sheet header.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final fill = tokens.phaseFill(phaseKey);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? ElaraSpacing.md : ElaraSpacing.xl,
        vertical: compact ? ElaraSpacing.xs : ElaraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(ElaraRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: compact
                ? context.type.subtitle(tokens.onPhase, size: 14)
                : context.type.headline(tokens.onPhase, size: 22),
          ),
          if (cycleDay != null) ...[
            SizedBox(width: compact ? ElaraSpacing.sm : ElaraSpacing.md),
            Text(
              'Day $cycleDay',
              style: (compact
                      ? context.type.label(tokens.onPhase)
                      : context.type.subtitle(tokens.onPhase))
                  .copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small square swatch used in the calendar legend and phase lists.
class PhaseSwatch extends StatelessWidget {
  const PhaseSwatch({super.key, required this.phaseKey, this.size = 10});

  final String phaseKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.phaseFill(phaseKey),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
