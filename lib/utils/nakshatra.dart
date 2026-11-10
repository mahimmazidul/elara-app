import 'moon_phase.dart';

/// A nakshatra: one of the 27 equal segments of the ecliptic.
class Nakshatra {
  const Nakshatra({
    required this.index,
    required this.name,
    required this.longitude,
    required this.degreesInto,
  });

  /// 0-based index, 0 = Ashwini.
  final int index;

  /// Traditional name.
  final String name;

  /// The Moon's sidereal longitude used for the division, 0..360.
  final double longitude;

  /// Degrees travelled into this segment, 0..13.333.
  final double degreesInto;

  /// 1-based number, as usually written.
  int get number => index + 1;

  /// The segment's width in degrees.
  static const double segmentWidth = 360 / 27; // 13°20'

  /// Canonical order of the 27 nakshatras.
  static const List<String> names = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishta',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  /// Computes the nakshatra for an instant, locally.
  ///
  /// The equatorial (tropical) ecliptic longitude from [moonEclipticLongitude]
  /// is converted to a sidereal longitude by subtracting the ayanamsa, as
  /// nakshatras are defined against the fixed stars. Lahiri's ayanamsa is used
  /// (the Indian national standard), approximated as
  ///
  ///   ayanamsa ≈ 23.85 + 0.013972 * (year - 2000)   degrees
  ///
  /// which is within a few arcminutes of the tabulated Lahiri values across the
  /// years this app will plausibly run. Accuracy note: combined with the ~0.3
  /// degree lunar residual, a Moon within roughly 0.4 degrees of a boundary may
  /// be assigned to the neighbouring nakshatra. The segment is 13.33 degrees
  /// wide, so this affects about 3% of instants and is not user-visible in a
  /// daily reading.
  factory Nakshatra.forDate(DateTime date) {
    final utc = date.toUtc();
    final jd = julianDate(utc);
    final tropical = moonEclipticLongitude(jd);
    final sidereal = _norm360(tropical - laharAyanamsa(jd));
    return Nakshatra.fromSiderealLongitude(sidereal);
  }

  /// Division itself, exposed so it can be verified independently of the
  /// astronomical model.
  factory Nakshatra.fromSiderealLongitude(double siderealLongitude) {
    final longitude = _norm360(siderealLongitude);
    final rawIndex = longitude / segmentWidth;
    var index = rawIndex.floor();
    if (index >= names.length) index = names.length - 1;
    if (index < 0) index = 0;
    return Nakshatra(
      index: index,
      name: names[index],
      longitude: longitude,
      degreesInto: longitude - index * segmentWidth,
    );
  }

  @override
  String toString() =>
      'Nakshatra($name, #$number, ${degreesInto.toStringAsFixed(2)}° in)';
}

/// Lahiri ayanamsa in degrees for a Julian Date.
double laharAyanamsa(double jd) {
  // Years since J2000.0 (a Julian year is 365.25 days).
  final years = (jd - 2451545.0) / 365.25;
  return 23.85 + 0.013972 * years;
}

double _norm360(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}
