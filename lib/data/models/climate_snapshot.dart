import 'dart:math' as math;

import 'package:elara_core/elara_core.dart' as core;

import '../date_keys.dart';

/// Computes apparent temperature from temperature and humidity.
class HeatIndexCalculator {
  HeatIndexCalculator._();

  /// Steadman apparent temperature in degrees Celsius.
  ///
  /// Implements the Steadman (1979) formula as adapted by the Australian
  /// Bureau of Meteorology, which is defined in Celsius. (The US NWS variant of
  /// the same formula is defined in Fahrenheit and gives the familiar "heat
  /// index" figures.)
  ///
  ///   AT = T + 0.33 * e - 0.70 * ws - 4.00
  ///   e  = (RH / 100) * 6.105 * exp(17.27 * T / (237.7 + T))
  ///
  /// The wind term assumes 1.0 m/s, because neither the Open-Meteo request nor
  /// the cache stores wind speed. This is the humidity-driven part of the
  /// Steadman calculation; it is documented so the assumption is not mistaken
  /// for a measured value.
  ///
  /// Returns [temperatureCelsius] unchanged when an input is not finite, so the
  /// result is always a usable number.
  static double steadman({
    required double temperatureCelsius,
    required double relativeHumidity,
  }) {
    if (!temperatureCelsius.isFinite) return 0;
    if (!relativeHumidity.isFinite) return temperatureCelsius;

    final t = temperatureCelsius;
    final rh = relativeHumidity.clamp(0.0, 100.0).toDouble();
    final vapourPressure = (rh / 100) * 6.105 * math.exp(17.27 * t / (237.7 + t));
    const assumedWindSpeed = 1.0; // m/s
    final apparent = t + 0.33 * vapourPressure - 0.70 * assumedWindSpeed - 4.00;
    return apparent.isFinite ? apparent : t;
  }
}

/// A one-day row of the `climate_cache` table.
///
/// Environmental values come from Open-Meteo (weather) and Open-AQ (PM2.5), or
/// from [ClimateSnapshot.seasonalFallback] when those calls fail. [isFallback]
/// exposes which, so the UI can label estimates as estimates instead of
/// presenting a seasonal average as a live measurement.
class ClimateSnapshot {
  ClimateSnapshot({
    this.id,
    required DateTime date,
    required this.temperature,
    required this.humidity,
    required this.heatIndex,
    required this.sunshineHours,
    required this.pm25,
    required this.aqiCategory,
    DateTime? fetchedAt,
    this.isFallback = false,
    this.seasonNote,
  })  : date = dateOnly(date),
        fetchedAt = fetchedAt ?? DateTime.now();

  final int? id;

  /// The calendar day these values describe.
  final DateTime date;

  /// Air temperature, degrees Celsius.
  final double temperature;

  /// Relative humidity, 0-100 percent.
  final double humidity;

  /// Steadman apparent temperature, degrees Celsius.
  final double heatIndex;

  /// Sunshine hours for the day.
  final double sunshineHours;

  /// PM2.5 concentration, micrograms per cubic metre.
  final double pm25;

  /// AQI band label, e.g. `Good` or `Moderate`.
  final String aqiCategory;

  /// When these values were obtained.
  final DateTime fetchedAt;

  /// True when generated from the seasonal table instead of a live reading.
  /// Derived at fetch time and carried in memory; not a database column.
  final bool isFallback;

  /// Season name for a fallback value, e.g. `Monsoon`. Null for live readings.
  final String? seasonNote;

  static const Duration cacheTtl = Duration(hours: 3);

  /// Whether [now] falls inside the three-hour freshness window.
  bool isFreshAt(DateTime now) {
    final age = now.difference(fetchedAt);
    // A clock change can make `age` negative; treat that as stale so the app
    // refetches rather than trusting a timestamp from the future.
    return !age.isNegative && age < cacheTtl;
  }

  /// Maps the snapshot onto elara-core's environment contract.
  ///
  /// core treats AQI as a 1-5 band rather than a label, and hydration as a
  /// user-reported 1-3 level, so both need a deliberate default here rather
  /// than a guess hidden inside the engine.
  core.EnvironmentConditions toEnvironmentConditions({
    int hydrationLevel = 2,
    core.Season? seasonOverride,
  }) {
    return core.EnvironmentConditions(
      heatIndex: heatIndex,
      pm25: pm25,
      aqiCategory: aqiBandFromLabel(aqiCategory),
      sunshineHours: sunshineHours.clamp(0, 24).toDouble(),
      season: seasonOverride ?? seasonFor(date),
      hydrationLevel: hydrationLevel.clamp(1, 3),
      humidityPercent: humidity.clamp(0, 100).toDouble(),
    );
  }

  /// Bangladesh seasons as used by elara-core's severity modifier.
  static core.Season seasonFor(DateTime date) {
    final month = date.month;
    if (month == 12 || month <= 2) return core.Season.winter;
    if (month <= 5) return core.Season.preMonsoon;
    if (month <= 9) return core.Season.monsoon;
    return core.Season.postMonsoon;
  }

  /// Bands a PM2.5 reading using US EPA breakpoints.
  static String aqiCategoryFor(double pm25) {
    if (pm25 <= 12.0) return 'Good';
    if (pm25 <= 35.4) return 'Moderate';
    if (pm25 <= 55.4) return 'Unhealthy for Sensitive Groups';
    if (pm25 <= 150.4) return 'Unhealthy';
    if (pm25 <= 250.4) return 'Very Unhealthy';
    return 'Hazardous';
  }

  /// Converts a stored band label back to elara-core's 1-5 scale. core rejects
  /// anything outside 1-5, so unknown labels fall back to a mid band.
  static int aqiBandFromLabel(String label) {
    switch (label) {
      case 'Good':
        return 1;
      case 'Moderate':
        return 2;
      case 'Unhealthy for Sensitive Groups':
        return 3;
      case 'Unhealthy':
        return 4;
      case 'Very Unhealthy':
      case 'Hazardous':
        return 5;
      default:
        return 2;
    }
  }

  /// Offline estimates for the date's season, used whenever a live fetch fails.
  ///
  /// These are long-run Bangladesh seasonal baselines, not a reading for any
  /// particular day; [isFallback] is set so callers can say so.
  factory ClimateSnapshot.seasonalFallback(DateTime date, {DateTime? now}) {
    final month = date.month;
    final String season;
    final double temperature;
    final double humidity;
    final double sunshine;
    final double pm25;

    if (month == 12 || month <= 2) {
      season = 'Winter';
      temperature = 18;
      humidity = 65;
      sunshine = 7.5;
      pm25 = 80;
    } else if (month <= 5) {
      season = 'Pre-monsoon';
      temperature = 32;
      humidity = 75;
      sunshine = 6;
      pm25 = 60;
    } else if (month <= 9) {
      season = 'Monsoon';
      temperature = 29;
      humidity = 90;
      sunshine = 3.5;
      pm25 = 35;
    } else {
      season = 'Post-monsoon';
      temperature = 26;
      humidity = 78;
      sunshine = 7;
      pm25 = 50;
    }

    return ClimateSnapshot(
      date: dateOnly(date),
      temperature: temperature,
      humidity: humidity,
      heatIndex: HeatIndexCalculator.steadman(
        temperatureCelsius: temperature,
        relativeHumidity: humidity,
      ),
      sunshineHours: sunshine,
      pm25: pm25,
      aqiCategory: aqiCategoryFor(pm25),
      fetchedAt: now ?? DateTime.now(),
      isFallback: true,
      seasonNote: season,
    );
  }

  factory ClimateSnapshot.fromMap(Map<String, Object?> map) {
    double readDouble(String column) {
      final value = map[column];
      return value == null ? 0 : (value as num).toDouble();
    }

    return ClimateSnapshot(
      id: map['id'] as int?,
      date: parseDateKey(map['date']! as String),
      temperature: readDouble('temperature'),
      humidity: readDouble('humidity'),
      heatIndex: readDouble('heat_index'),
      sunshineHours: readDouble('sunshine_hours'),
      pm25: readDouble('pm25'),
      aqiCategory: (map['aqi_category'] as String?) ?? 'Unknown',
      fetchedAt: DateTime.parse(map['fetched_at']! as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) => {
        if (includeId && id != null) 'id': id,
        'date': dateKey(date),
        'temperature': temperature,
        'humidity': humidity,
        'heat_index': heatIndex,
        'sunshine_hours': sunshineHours,
        'pm25': pm25,
        'aqi_category': aqiCategory,
        'fetched_at': timestampKey(fetchedAt),
      };

  @override
  String toString() =>
      'ClimateSnapshot(${dateKey(date)}: ${temperature.toStringAsFixed(1)}C, '
      '${humidity.toStringAsFixed(0)}% RH, '
      'HI ${heatIndex.toStringAsFixed(1)}, '
      '${sunshineHours.toStringAsFixed(1)}h sun, '
      'PM2.5 ${pm25.toStringAsFixed(0)} '
      '[${isFallback ? 'fallback' : 'live'}])';
}
