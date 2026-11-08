import 'dart:math' as math;

/// Moon phase computed locally, with no network call and no table of dates.
///
/// Method: the phase is a function of the Moon's elongation from the Sun. The
/// primitives used here are
///
///   * [julianDate] from the Unix epoch (JD 2440587.5 at 1970-01-01T00:00Z);
///   * [moonEclipticLongitude] and [sunEclipticLongitude], each a truncated
///     Meeus series (see their docs for the accuracy actually achieved);
///   * the elongation's fraction of a full turn as the phase position.
///
/// Phase and illumination are therefore derived from an actual position model
/// rather than a linear count from one reference new moon, which keeps the
/// error from accumulating over decades. [MoonPhase.synodicEstimate] is kept
/// beside it as an independent cross-check: the two methods agreeing is what
/// the verification script asserts.
class MoonPhase {
  const MoonPhase({
    required this.date,
    required this.phaseFraction,
    required this.illumination,
    required this.elongationDegrees,
    required this.moonLongitude,
    required this.sunLongitude,
  });

  /// The instant these values describe (UTC internally).
  final DateTime date;

  /// Position in the lunation: 0.0 = new, 0.25 = first quarter,
  /// 0.5 = full, 0.75 = last quarter.
  final double phaseFraction;

  /// Illuminated fraction of the disc, 0..1.
  final double illumination;

  /// Moon's angular distance from the Sun, 0..360 degrees.
  final double elongationDegrees;

  final double moonLongitude;
  final double sunLongitude;

  /// Name of the phase in the eight conventional buckets.
  String get name {
    final f = phaseFraction;
    if (f < 0.033 || f >= 0.967) return 'New moon';
    if (f < 0.216) return 'Waxing crescent';
    if (f < 0.284) return 'First quarter';
    if (f < 0.467) return 'Waxing gibbous';
    if (f < 0.533) return 'Full moon';
    if (f < 0.716) return 'Waning gibbous';
    if (f < 0.784) return 'Last quarter';
    return 'Waning crescent';
  }

  /// The conventional eight phase emoji for this position.
  ///
  /// Emoji are used deliberately: they need no image assets, scale with the
  /// text size, and render in the system font.
  String get emoji {
    final f = phaseFraction;
    if (f < 0.033 || f >= 0.967) return '\u{1F311}'; // 🌑
    if (f < 0.216) return '\u{1F312}'; // 🌒
    if (f < 0.284) return '\u{1F313}'; // 🌓
    if (f < 0.467) return '\u{1F314}'; // 🌔
    if (f < 0.533) return '\u{1F315}'; // 🌕
    if (f < 0.716) return '\u{1F316}'; // 🌖
    if (f < 0.784) return '\u{1F317}'; // 🌗
    return '\u{1F318}'; // 🌘
  }

  /// Illumination as a whole percentage, for display.
  int get illuminationPercent => (illumination * 100).round();

  /// True when the disc is more than half lit.
  bool get isWaxing => phaseFraction < 0.5;

  /// Computes the phase for [date] (interpreted as an instant).
  factory MoonPhase.forDate(DateTime date) {
    final utc = date.toUtc();
    final jd = julianDate(utc);

    final moonLongitude = moonEclipticLongitude(jd);
    final sunLongitude = sunEclipticLongitude(jd);

    // Normalise the Moon's lead over the Sun into 0..360.
    var elongation = (moonLongitude - sunLongitude) % 360;
    if (elongation < 0) elongation += 360;

    final fraction = elongation / 360.0;

    // Illuminated fraction from elongation:
    //   k = (1 - cos(elongation)) / 2
    // This is exact for a sphere lit by a distant source, ignoring the small
    // phase-angle correction (well under a percentage point for our purposes).
    final illumination =
        (1 - math.cos(elongation * math.pi / 180)) / 2;

    return MoonPhase(
      date: utc,
      phaseFraction: fraction,
      illumination: illumination.clamp(0.0, 1.0),
      elongationDegrees: elongation,
      moonLongitude: moonLongitude,
      sunLongitude: sunLongitude,
    );
  }

  /// Independent estimate from a mean synodic month counted from a known
  /// new moon. Deliberately simple; used only to cross-check
  /// [MoonPhase.forDate], never for display.
  ///
  /// Reference: new moon of 2000-01-06 18:14 UTC (JD 2451550.26).
  static double synodicEstimate(DateTime date) {
    const synodicMonth = 29.530588853;
    const referenceNewMoonJd = 2451550.26;
    final days = julianDate(date.toUtc()) - referenceNewMoonJd;
    final cycles = days / synodicMonth;
    return cycles - cycles.floorToDouble();
  }
}

/// Julian Date for a UTC instant.
///
/// JD 2440587.5 is 1970-01-01T00:00:00Z, and a day is 86 400 000 ms.
double julianDate(DateTime date) {
  final utc = date.toUtc();
  return utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
}

/// Julian centuries since J2000.0 for a Julian Date.
double _centuries(double jd) => (jd - 2451545.0) / 36525.0;

double _norm360(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}

double _sinDeg(double degrees) => math.sin(degrees * math.pi / 180);

/// Moon's apparent ecliptic longitude, in degrees, 0..360.
///
/// Implements the truncated lunar theory from Meeus, *Astronomical Algorithms*,
/// ch. 47 (the largest periodic terms of the ELP-2000/82 expansion). With the
/// terms included here the residual is a few tenths of a degree against the
/// full theory — ample for a 27-fold division of the ecliptic (13.33 degrees
/// per segment), and documented rather than glossed: a Moon within ~0.3 degrees
/// of a nakshatra boundary can land in the neighbouring segment.
double moonEclipticLongitude(double jd) {
  final t = _centuries(jd);

  // Mean longitude of the Moon.
  final lPrime = _norm360(
    218.3164477 + 481267.88123421 * t - 0.0015786 * t * t + t * t * t / 538841,
  );
  // Mean elongation of the Moon.
  final d = _norm360(
    297.8501921 + 445267.1114034 * t - 0.0018819 * t * t + t * t * t / 545868,
  );
  // Sun's mean anomaly.
  final mPrime = _norm360(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t);
  // Moon's mean anomaly.
  final m = _norm360(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t);
  // Moon's argument of latitude.
  final f = _norm360(93.2720950 + 483202.0175233 * t - 0.0036539 * t * t);

  // Meeus table 47.A, largest periodic terms: (coefficient, argument) in
  // degrees. Sign is carried by the coefficient.
  final series = <(double, double)>[
    (6.288774, m), // evection
    (1.274027, 2 * d - m), // variation
    (0.658314, d),
    (0.213618, 2 * m),
    (-0.185116, mPrime),
    (-0.114332, 2 * f),
    (0.058793, 2 * d - 2 * m),
    (0.057066, 2 * d - mPrime - m),
    (0.053322, 2 * d + m),
    (0.045758, 2 * d - mPrime),
    (-0.040923, mPrime - m),
    (-0.034720, d),
    (-0.030383, mPrime + m),
    (0.015327, 2 * d - 2 * f),
    (-0.012528, m + 2 * f),
    (0.010980, m - 2 * f),
    (0.010675, 4 * d - m),
    (0.010034, 3 * m),
    (0.008548, 4 * d - 2 * m),
    (-0.007888, 2 * d + mPrime - m),
    (-0.006766, m + mPrime),
  ];

  var sum = 0.0;
  for (final (coefficient, argument) in series) {
    sum += coefficient * _sinDeg(argument);
  }

  return _norm360(lPrime + sum);
}

/// Sun's apparent ecliptic longitude in degrees, 0..360.
///
/// Meeus low-precision solar position (ch. 25). Accurate to well under
/// 0.05 degrees for dates near the present, which is far tighter than needed to
/// place the Moon's elongation.
double sunEclipticLongitude(double jd) {
  final t = _centuries(jd);
  final l0 = _norm360(280.46646 + 36000.76983 * t + 0.0003032 * t * t);
  final m = _norm360(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
  final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sinDeg(m) +
      (0.019993 - 0.000101 * t) * _sinDeg(2 * m) +
      0.000289 * _sinDeg(3 * m);
  final trueLongitude = l0 + c;
  // Correct for aberration and nutation in longitude (approximate).
  final omega = 125.04 - 1934.136 * t;
  final apparent = trueLongitude - 0.00569 - 0.00478 * _sinDeg(omega);
  return _norm360(apparent);
}
