import 'package:material_ui/material_ui.dart';

import '../theme/elara_motion.dart';
import '../theme/elara_theme.dart';
import 'motion.dart';

/// The phase chip on the Today screen.
///
/// Filled with the phase colour and labelled in [ElaraTokens.onPhase], which is
/// the one ink that clears AA against all four fills (measured 5.2-9.1:1 in
/// light mode, 5.7-10.0:1 in dark).
///
/// The non-compact variant used to be a 22pt headline in a tall pill, which made
/// the phase the loudest object on a screen whose point is what to *do*. It now
/// sits at subtitle size: still the first thing read after the date, no longer
/// shouting. The day number is part of the same chip rather than repeated in a
/// line of body text underneath.
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

    // The fill moves when the phase changes, which happens when a cycle start
    // is logged. A cross-fade makes that read as the same chip showing a new
    // state; a snap makes it read as the screen reloading. It is skipped
    // entirely when the platform has asked for animations to be removed.
    return ElaraAnimatedColor(
      color: fill,
      borderRadius: ElaraRadii.chip,
      duration: ElaraMotion.medium,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? ElaraSpacing.md : ElaraSpacing.lg,
          vertical: compact ? ElaraSpacing.xs : ElaraSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible so a long phase name ("Luteal (late)") plus a day
            // number cannot push the chip past its parent's width.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? context.type.subtitle(tokens.onPhase, size: 14)
                    : context.type.subtitle(tokens.onPhase, size: 15),
              ),
            ),
            if (cycleDay != null) ...[
              SizedBox(width: compact ? ElaraSpacing.sm : ElaraSpacing.md),
              Text(
                'Day $cycleDay',
                style:
                    (compact
                            ? context.type.label(tokens.onPhase)
                            : context.type.caption(tokens.onPhase))
                        .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
              ),
            ],
          ],
        ),
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
