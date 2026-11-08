import 'package:flutter/material.dart';

import '../../theme/elara_theme.dart';
import '../../utils/hijri_date.dart';
import '../../utils/moon_phase.dart';
import '../../widgets/moon_glyph.dart';
import '../../utils/nakshatra.dart';

/// Bottom strip: Islamic date, moon phase and nakshatra.
///
/// All three are computed on-device from the date — there is no network call in
/// this file. [MoonPhase] and [Nakshatra] each derive their answer from an
/// astronomical position model; [HijriDate] uses the Umm al-Qura calendar, which
/// is calculated rather than sighting-based.
class LunarStrip extends StatelessWidget {
  const LunarStrip({super.key, this.date});

  /// Defaults to now.
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final moment = date ?? DateTime.now();

    final hijri = HijriDate.forDate(moment);
    final moon = MoonPhase.forDate(moment);
    final nakshatra = Nakshatra.forDate(moment);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ElaraSpacing.lg,
        vertical: ElaraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.moonGlow,
        borderRadius: BorderRadius.circular(ElaraRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Cell(
              label: 'Hijri',
              child: Text(
                hijri.formatted,
                style: type.label(tokens.textPrimary, size: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _Cell(
            label: 'Moon',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoonGlyph(phaseFraction: moon.phaseFraction, size: 18),
                const SizedBox(width: ElaraSpacing.xs),
                Text(
                  '${moon.illuminationPercent}%',
                  style: type.number(tokens.textPrimary, size: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _Cell(
              label: 'Nakshatra',
              alignEnd: true,
              child: Text(
                nakshatra.name,
                style: type.label(tokens.textPrimary, size: 12),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.child,
    this.alignEnd = false,
  });

  final String label;
  final Widget child;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: context.type.overline(tokens.textSecondaryStrong).copyWith(
                fontSize: 9,
              ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}
