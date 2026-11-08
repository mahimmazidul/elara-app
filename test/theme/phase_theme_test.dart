import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
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

  group('the 8% surface tint', () {
    test('is applied to the page and card surfaces', () {
      final base = ElaraPalette.light;
      final tinted = ElaraTheme.paletteFor(base, 'menstrual');

      expect(tinted.bgPrimary, isNot(base.bgPrimary));
      expect(tinted.bgCard, isNot(base.bgCard));

      // 8% of the phase colour, composited over the original surface.
      final expectedCard = Color.alphaBlend(
        base.phaseMenstrual.withValues(alpha: ElaraTheme.surfaceTintOpacity),
        base.bgCard,
      );
      expect(tinted.bgCard, expectedCard);
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
    test('every style is DM Sans', () {
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
        expect(style.fontFamily, 'DM Sans');
      }
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
      // A requested weight still resolves to one of the bundled three.
      expect(
        type.number(const Color(0xFF000000), weight: FontWeight.w600)
            .fontWeight,
        FontWeight.w700,
      );
    });
  });
}
