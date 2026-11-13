import 'package:material_ui/material_ui.dart';

import '../../theme/elara_theme.dart';
import '../../utils/hijri_date.dart';
import '../../utils/moon_phase.dart';
import '../../widgets/moon_glyph.dart';
import '../../widgets/primitives.dart';
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

    // A tinted block used to sit here, making the calendars the second-loudest
    // object on a screen about care. They are reference information: a hairline
    // and a little padding say that without pretending to be empty space.
    return Container(
      padding: const EdgeInsets.only(
        top: ElaraSpacing.md,
        bottom: ElaraSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The moon gets its own line because it is the one astronomical
          // value most people actually look at.
          //
          // The name is English. It used to be the Bangla bucket name, which
          // read as broken text: the bundled font had no Bengali layout tables,
          // so a compound like শুক্লপক্ষের came out as loose consonants and
          // misplaced vowel signs. The font is fixed (tool/fonts/), but the
          // label stays English anyway — "Waxing crescent" is what this line is
          // for, and the eight Bangla names for the quarter phases were
          // descriptive rather than everyday words.
          Row(
            children: [
              MoonGlyph(phaseFraction: moon.phaseFraction, size: 22),
              const SizedBox(width: ElaraSpacing.sm),
              Expanded(
                child: Text(
                  moon.name,
                  style: type.body(tokens.textPrimary),
                ),
              ),
              const SizedBox(width: ElaraSpacing.sm),
              NumberText(
                moon.illuminationLabel,
                style: type.caption(tokens.textSecondaryStrong),
              ),
            ],
          ),
          const SizedBox(height: ElaraSpacing.sm),
          // Hijri and nakshatra share a line that wraps rather than truncates:
          // both are reference information the reader may want in full.
          Wrap(
            spacing: ElaraSpacing.lg,
            runSpacing: ElaraSpacing.xxs,
            children: [
              _Pair(label: 'Hijri', value: hijri.formatted),
              _Pair(label: 'Nakshatra', value: nakshatra.name),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small `label value` pair used by the calendar line.
class _Pair extends StatelessWidget {
  const _Pair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: type.caption(tokens.textSecondaryStrong, size: 12),
        ),
        const SizedBox(width: ElaraSpacing.xs),
        Text(value, style: type.label(tokens.textPrimary, size: 12)),
      ],
    );
  }
}
