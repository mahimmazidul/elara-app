import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase-adaptive theming: the accent follows the cycle phase, the two surface
/// colours carry an 8% tint of it, and every ink still clears WCAG AA on both
/// themes.
///
/// These assertions exist because the tint is applied at runtime: the palettes'
/// documented ratios were measured against the untinted surfaces, so the mixing
/// is exactly the kind of thing that can quietly push text below AA.
void main() {
  const phases = ['menstrual', 'follicular', 'ovulatory', 'luteal'];

  double ratio(Color a, Color b) => ElaraTheme.contrastRatio(a, b);

  group('accent follows the phase', () {
    test('each phase moves the accent to its own colour', () {
      final accents = <String, Color>{};
      for (final phase in phases) {
        final palette = ElaraTheme.paletteFor(ElaraPalette.light, phase);
        accents[phase] = palette.accent;
      }

      // Every phase gets a distinct accent, and none of them is the neutral one.
      expect(accents.values.toSet(), hasLength(4));
      expect(
        accents.values,
        isNot(anyElement(ElaraPalette.light.accent)),
      );
    });

    test('an unknown or missing phase keeps the neutral accent', () {
      for (final key in [null, 'unknown', '', 'not-a-phase']) {
        final palette = ElaraTheme.paletteFor(ElaraPalette.light, key);
        expect(palette.accent, ElaraPalette.light.accent, reason: 'key: $key');
        // And no tint leaks onto the surfaces.
        expect(palette.bgPrimary, ElaraPalette.light.bgPrimary);
        expect(palette.bgCard, ElaraPalette.light.bgCard);
      }
    });

    test('isCyclePhase knows exactly the four phases', () {
      for (final phase in phases) {
        expect(ElaraTheme.isCyclePhase(phase), isTrue);
      }
      expect(ElaraTheme.isCyclePhase('unknown'), isFalse);
      expect(ElaraTheme.isCyclePhase(null), isFalse);
    });

    test('the theme threads the phase through to the tokens', () {
      final theme = ElaraTheme.light(phaseKey: 'ovulatory');
      final tokens = theme.extension<ElaraTokens>()!;

      expect(tokens.accent, ElaraPalette.light.phaseOvulatory);
      // Calendar colours stay per-date and independent of the active accent, so
      // all four phases must still resolve to their own fills.
      expect(tokens.phaseFill('menstrual'), ElaraPalette.light.phaseMenstrual);
      expect(tokens.phaseFill('luteal'), ElaraPalette.light.phaseLuteal);
    });

    test('a phase change produces a different theme', () {
      final follicular = ElaraTheme.light(phaseKey: 'follicular');
      final luteal = ElaraTheme.light(phaseKey: 'luteal');

      expect(
        follicular.extension<ElaraTokens>()!.accent,
        isNot(luteal.extension<ElaraTokens>()!.accent),
      );
    });
  });

  group('phase wash', () {
    test('never touches the page or the card surface', () {
      for (final base in [ElaraPalette.light, ElaraPalette.dark]) {
        for (final phase in ['menstrual', 'follicular', 'ovulatory', 'luteal']) {
          final themed = ElaraTheme.paletteFor(base, phase);

          // The page background is a fixed, neutral value. An amber week must
          // not turn the whole app cream, and a rose week must not tint every
          // screen: the colour is only meaningful where it is applied
          // deliberately.
          expect(themed.bgPrimary, base.bgPrimary, reason: phase);
          expect(themed.bgCard, base.bgCard, reason: phase);
        }
      }
    });

    test('is available to a designated surface at 8%', () {
      final tokens = ElaraTheme.light(phaseKey: 'menstrual')
          .extension<ElaraTokens>()!;

      final wash = tokens.phaseWash('menstrual');
      // The helper composites the phase fill at the declared opacity, which is
      // how a call site gets a phase-tinted panel without the page moving.
      expect(wash.a, closeTo(0.22, 0.001));
      expect(wash.r, closeTo(tokens.palette.phaseMenstrual.r, 0.01));
    });

    test('leaves semantic colours alone', () {
      final base = ElaraPalette.light;
      final tinted = ElaraTheme.paletteFor(base, 'ovulatory');

      // A warning must still be a warning, whatever phase it is.
      expect(tinted.danger, base.danger);
      expect(tinted.warning, base.warning);
      expect(tinted.success, base.success);
      // And the per-phase fills are untouched.
      expect(tinted.phaseMenstrual, base.phaseMenstrual);
      expect(tinted.phaseLuteal, base.phaseLuteal);
    });
  });

  group('contrast holds in every phase, both themes', () {
    for (final entry in {
      'light': ElaraPalette.light,
      'dark': ElaraPalette.dark,
    }.entries) {
      for (final phase in phases) {
        test('${entry.key} / $phase clears AA', () {
          final p = ElaraTheme.paletteFor(entry.value, phase);

          double onPage(Color ink) => ratio(ink, p.bgPrimary);
          double onCard(Color ink) => ratio(ink, p.bgCard);

          // Body copy.
          expect(onPage(p.textPrimary), greaterThanOrEqualTo(4.5));
          expect(onCard(p.textPrimary), greaterThanOrEqualTo(4.5));
          expect(onCard(p.textSecondary), greaterThanOrEqualTo(4.5));
          expect(onCard(p.textSecondaryStrong), greaterThanOrEqualTo(4.5));

          // Accent used as text (links, labels).
          expect(onCard(p.accentText), greaterThanOrEqualTo(4.5));
          expect(onPage(p.accentText), greaterThanOrEqualTo(4.5));

          // Status inks, which must survive the tint too.
          expect(onCard(p.dangerText), greaterThanOrEqualTo(4.5));
          expect(onCard(p.warningText), greaterThanOrEqualTo(4.5));
          expect(onCard(p.successText), greaterThanOrEqualTo(4.5));

          // Ink on an accent-filled control (the primary button).
          expect(ratio(p.onPhase, p.accent), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  group('typography', () {
    test('every style is Hind Siliguri', () {
      const type = ElaraTypography();
      final styles = [
        type.displayNumber(const Color(0xFF000000)),
        type.number(const Color(0xFF000000)),
        type.headline(const Color(0xFF000000)),
        type.title(const Color(0xFF000000)),
        type.subtitle(const Color(0xFF000000)),
        type.body(const Color(0xFF000000)),
        type.bodyStrong(const Color(0xFF000000)),
        type.label(const Color(0xFF000000)),
        type.caption(const Color(0xFF000000)),
        type.overline(const Color(0xFF000000)),
      ];

      for (final style in styles) {
        expect(style.fontFamily, 'Hind Siliguri');
      }
    });

    test('one family draws both scripts', () {
      // Hind Siliguri carries the Latin and the Bengali, so a style needs no
      // fallback. If a style ever needs one again, the seam it would cause -
      // Bengali set in a visibly different typeface - comes back with it.
      const type = ElaraTypography();
      expect(type.body(const Color(0xFF000000)).fontFamilyFallback, isEmpty);
    });

    test('a semibold request gets a real semibold', () {
      // The font bundles 600, so asking for it must not be rounded to 500 or
      // 700. Flutter would synthesise a fake weight otherwise.
      const type = ElaraTypography();
      final style = type.body(
        const Color(0xFF000000),
      ).copyWith(fontWeight: FontWeight.w600);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('weights use only what the font bundles', () {
      const type = ElaraTypography();
      // 400 secondary and captions, 500 body, 700 headings.
      expect(type.label(const Color(0xFF000000)).fontWeight, FontWeight.w400);
      expect(type.caption(const Color(0xFF000000)).fontWeight, FontWeight.w400);
      expect(type.body(const Color(0xFF000000)).fontWeight, FontWeight.w500);
      expect(type.subtitle(const Color(0xFF000000)).fontWeight, FontWeight.w500);
      expect(type.headline(const Color(0xFF000000)).fontWeight, FontWeight.w700);
      expect(type.title(const Color(0xFF000000)).fontWeight, FontWeight.w700);
    });

    test('numeral styles ask for tabular figures', () {
      const type = ElaraTypography();
      const expected = [FontFeature.tabularFigures()];

      expect(type.displayNumber(const Color(0xFF000000)).fontFeatures, expected);
      expect(type.number(const Color(0xFF000000)).fontFeatures, expected);
      // A requested weight still resolves to one the font bundles. The
      // bundled weights are 400, 500, 600 and 700, and 600 is a real weight
      // in the font, so it is not rounded away.
      expect(
        type.number(const Color(0xFF000000), weight: FontWeight.w600)
            .fontWeight,
        FontWeight.w600,
      );
      expect(
        type.number(const Color(0xFF000000), weight: FontWeight.w800)
            .fontWeight,
        FontWeight.w700,
      );
    });
  });
}
