import 'package:elara_app/utils/nakshatra.dart';
import 'package:flutter_test/flutter_test.dart';

/// A nakshatra is the 27-fold division of the sidereal ecliptic. The index it
/// returns indexes `Nakshatra.names`, so the two things that must never break
/// are the range and the alignment with that list.
void main() {
  group('index range', () {
    test('every day of a decade lands between 0 and 26', () {
      var date = DateTime.utc(2020, 1, 1);
      final end = DateTime.utc(2030, 1, 1);

      while (date.isBefore(end)) {
        final nakshatra = Nakshatra.forDate(date);
        expect(
          nakshatra.index,
          inInclusiveRange(0, 26),
          reason: 'index out of range on $date',
        );
        expect(nakshatra.name, Nakshatra.names[nakshatra.index]);
        expect(nakshatra.number, nakshatra.index + 1);
        expect(nakshatra.degreesInto, inInclusiveRange(0.0, Nakshatra.segmentWidth));
        date = date.add(const Duration(days: 1));
      }
    });

    test('hourly sampling never escapes the range', () {
      var date = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 24 * 60; i++) {
        expect(Nakshatra.forDate(date).index, inInclusiveRange(0, 26));
        date = date.add(const Duration(hours: 1));
      }
    });

    test('there are exactly 27 names', () {
      expect(Nakshatra.names, hasLength(27));
      expect(Nakshatra.names.first, 'Ashwini');
    });
  });

  group('division', () {
    test('0 degrees is Ashwini and each segment advances by one index', () {
      expect(Nakshatra.fromSiderealLongitude(0).index, 0);
      expect(Nakshatra.fromSiderealLongitude(0).name, 'Ashwini');

      for (var i = 0; i < 27; i++) {
        final start = i * Nakshatra.segmentWidth;
        // Sample just inside the segment so floating point cannot push the
        // boundary case into the previous index.
        final nakshatra =
            Nakshatra.fromSiderealLongitude(start + Nakshatra.segmentWidth / 2);
        expect(nakshatra.index, i, reason: 'segment $i');
      }
    });

    test('longitudes wrap instead of overflowing the index', () {
      expect(Nakshatra.fromSiderealLongitude(360).index, 0);
      expect(Nakshatra.fromSiderealLongitude(720 + 90).index,
          Nakshatra.fromSiderealLongitude(90).index);
      // A negative longitude is normalised into the circle, never clamped to 0.
      expect(Nakshatra.fromSiderealLongitude(-10).index, 26);
    });

    test('the segment width is one twenty-seventh of the circle', () {
      expect(Nakshatra.segmentWidth, closeTo(13.3333, 0.0001));
    });
  });
}
