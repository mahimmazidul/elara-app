import 'package:elara_app/utils/moon_phase.dart';
import 'package:flutter_test/flutter_test.dart';

/// The moon phase drives the lunar strip and the nakshatra division, so the
/// contract that matters is narrow and testable: whatever instant you hand in,
/// the phase fraction lands inside one lunation and the illumination inside one
/// disc. The astronomy behind it is verified separately against published
/// ephemerides; these tests pin the range and a few known instants.
void main() {
  group('phase fraction', () {
    test('stays between 0.0 and 1.0 for every day of a decade', () {
      var date = DateTime.utc(2020, 1, 1);
      final end = DateTime.utc(2030, 1, 1);

      while (date.isBefore(end)) {
        final phase = MoonPhase.forDate(date);
        expect(
          phase.phaseFraction,
          inInclusiveRange(0.0, 1.0),
          reason: 'phaseFraction out of range on $date',
        );
        expect(
          phase.illumination,
          inInclusiveRange(0.0, 1.0),
          reason: 'illumination out of range on $date',
        );
        expect(
          phase.elongationDegrees,
          inInclusiveRange(0.0, 360.0),
          reason: 'elongation out of range on $date',
        );
        date = date.add(const Duration(days: 1));
      }
    });

    test('stays in range at sub-day resolution, including the wrap point', () {
      // Sampling every 6 hours walks across the 0/1 boundary repeatedly, which
      // is where a naive normalisation would return -0.02 or 1.01.
      var date = DateTime.utc(2026, 3, 1);
      for (var i = 0; i < 400; i++) {
        final phase = MoonPhase.forDate(date);
        expect(phase.phaseFraction, inInclusiveRange(0.0, 1.0));
        expect(phase.illumination, inInclusiveRange(0.0, 1.0));
        date = date.add(const Duration(hours: 6));
      }
    });

    test('the same instant always produces the same value', () {
      final instant = DateTime.utc(2026, 11, 8, 12);
      final first = MoonPhase.forDate(instant);
      final second = MoonPhase.forDate(instant);

      expect(first.phaseFraction, second.phaseFraction);
      expect(first.illumination, second.illumination);
      expect(first.moonLongitude, second.moonLongitude);
    });

    test('a local DateTime is normalised to the same instant as its UTC twin',
        () {
      final utc = DateTime.utc(2026, 6, 15, 3);
      final local = utc.toLocal();

      expect(MoonPhase.forDate(utc).phaseFraction,
          closeTo(MoonPhase.forDate(local).phaseFraction, 1e-12));
    });
  });

  group('known lunations', () {
    test('the new moon of 2024-09-03 reads as almost unlit', () {
      // New moon 2024-09-03 01:55 UTC.
      final phase = MoonPhase.forDate(DateTime.utc(2024, 9, 3, 1, 55));
      expect(phase.illumination, lessThan(0.01));
      expect(phase.phaseFraction, anyOf(lessThan(0.01), greaterThan(0.99)));
    });

    test('the full moon of 2024-08-19 reads as almost fully lit', () {
      // Blue moon 2024-08-19 18:26 UTC.
      final phase = MoonPhase.forDate(DateTime.utc(2024, 8, 19, 18, 26));
      expect(phase.illumination, greaterThan(0.98));
      expect(phase.phaseFraction, closeTo(0.5, 0.02));
    });

    test('a first quarter sits a quarter of the way through the lunation', () {
      // First quarter 2024-09-11 06:06 UTC.
      final phase = MoonPhase.forDate(DateTime.utc(2024, 9, 11, 6, 6));
      expect(phase.phaseFraction, closeTo(0.25, 0.03));
      expect(phase.illumination, closeTo(0.5, 0.06));
    });

    test('waxing and waning flags agree with the fraction', () {
      final waxing = MoonPhase.forDate(DateTime.utc(2024, 9, 9));
      final waning = MoonPhase.forDate(DateTime.utc(2024, 9, 25));

      expect(waxing.isWaxing, isTrue);
      expect(waning.isWaxing, isFalse);
    });
  });

  group('cross-check', () {
    test('the position model and the synodic estimate stay within a day', () {
      // Two independent methods: Meeus longitudes against a mean synodic month
      // counted from a reference new moon. Drift between them would show up as
      // the difference widening over the years, so the sample spans 2000-2050.
      for (var year = 2000; year <= 2050; year += 5) {
        final date = DateTime.utc(year, 6, 15);
        final phase = MoonPhase.forDate(date);
        final estimate = MoonPhase.synodicEstimate(date);

        // Compare as circular distance in fractions of a lunation.
        var delta = (phase.phaseFraction - estimate).abs();
        if (delta > 0.5) delta = 1 - delta;

        // 0.035 of a lunation is about a day.
        expect(delta, lessThan(0.035), reason: 'divergence in $year');
      }
    });

    test('the julian date matches known epoch values', () {
      expect(julianDate(DateTime.utc(2000, 1, 1, 12)), closeTo(2451545.0, 1e-6));
      expect(julianDate(DateTime.utc(1970, 1, 1)), closeTo(2440587.5, 1e-6));
    });
  });
}
