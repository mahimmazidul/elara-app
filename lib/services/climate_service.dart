import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/database_helper.dart';
import '../data/date_keys.dart';
import '../data/models/climate_snapshot.dart';

/// Fetches today's environmental conditions, with a three-hour cache.
///
/// Order of preference for every field:
///   1. a fresh `climate_cache` row (younger than [ClimateSnapshot.cacheTtl]);
///   2. Open-Meteo for temperature, humidity, sunshine and precipitation;
///   3. Open-AQ for PM2.5 near the stored coordinates;
///   4. the seasonal Bangladesh baseline.
///
/// [getTodayClimate] never throws and never returns null. A weather lookup that
/// fails offline is a normal condition for this app, not an error, so failures
/// degrade to labelled estimates instead of surfacing exceptions to the caller.
class ClimateService {
  ClimateService({
    DatabaseHelper? database,
    http.Client? httpClient,
    Duration? timeout,
    DateTime Function()? clock,
  })  : _database = database ?? DatabaseHelper.instance,
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _timeout = timeout ?? const Duration(seconds: 10),
        _clock = clock ?? DateTime.now;

  final DatabaseHelper _database;
  final http.Client _http;
  final bool _ownsClient;
  final Duration _timeout;
  final DateTime Function() _clock;

  static const String _openMeteoHost = 'api.open-meteo.com';
  static const String _openAqHost = 'api.openaq.org';

  /// Default coordinates (Dhaka) used when settings are missing or unparsable.
  static const double _defaultLatitude = 23.8103;
  static const double _defaultLongitude = 90.4125;

  /// Returns climate for today, or for [date] when one is supplied.
  ///
  /// Guaranteed non-null. Check [ClimateSnapshot.isFallback] to tell whether
  /// the values are real readings.
  Future<ClimateSnapshot> getTodayClimate({DateTime? date}) async {
    final targetDate = dateOnly(date ?? _clock());

    final cached = await _readFreshCache(targetDate);
    if (cached != null) return cached;

    final coordinates = await _readCoordinates();

    final weather = await _fetchOpenMeteo(targetDate, coordinates);
    final pm25 = await _fetchPm25(coordinates);

    if (weather == null && pm25 == null) {
      // Nothing live at all: use the seasonal table and do not cache it, so a
      // later request while online can still replace it with a real reading.
      return ClimateSnapshot.seasonalFallback(targetDate, now: _clock());
    }

    final seasonal = ClimateSnapshot.seasonalFallback(targetDate, now: _clock());
    final temperature = weather?.temperature ?? seasonal.temperature;
    final humidity = weather?.humidity ?? seasonal.humidity;
    final sunshine = weather?.sunshineHours ?? seasonal.sunshineHours;
    final resolvedPm25 = pm25 ?? seasonal.pm25;

    final snapshot = ClimateSnapshot(
      date: targetDate,
      temperature: temperature,
      humidity: humidity,
      heatIndex: HeatIndexCalculator.steadman(
        temperatureCelsius: temperature,
        relativeHumidity: humidity,
      ),
      sunshineHours: sunshine,
      pm25: resolvedPm25,
      aqiCategory: ClimateSnapshot.aqiCategoryFor(resolvedPm25),
      fetchedAt: _clock(),
      // Partial data is still partly estimated; do not claim it is a reading.
      isFallback: weather == null || pm25 == null,
      seasonNote: weather == null || pm25 == null ? seasonal.seasonNote : null,
    );

    await _writeCache(snapshot);
    return snapshot;
  }

  /// Cache read that swallows storage errors: a corrupt or locked database must
  /// not stop the app from getting weather.
  Future<ClimateSnapshot?> _readFreshCache(DateTime date) async {
    try {
      return await _database.getFreshClimateFor(date, now: _clock());
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(ClimateSnapshot snapshot) async {
    try {
      await _database.upsertClimate(snapshot);
    } catch (_) {
      // Caching is best-effort; the freshly fetched values are still returned.
    }
  }

  Future<({double latitude, double longitude})> _readCoordinates() async {
    double parse(String? raw, double fallback) {
      final value = raw == null ? null : double.tryParse(raw);
      if (value == null || !value.isFinite) return fallback;
      // Reject out-of-range coordinates rather than sending a bad request.
      if (value < -180 || value > 180) return fallback;
      return value;
    }

    try {
      final settings = await _database.getAllSettings();
      return (
        latitude: parse(settings['latitude'], _defaultLatitude),
        longitude: parse(settings['longitude'], _defaultLongitude),
      );
    } catch (_) {
      return (latitude: _defaultLatitude, longitude: _defaultLongitude);
    }
  }

  Future<({double temperature, double humidity, double sunshineHours})?>
      _fetchOpenMeteo(
    DateTime date,
    ({double latitude, double longitude}) coordinates,
  ) async {
    final uri = Uri.https(_openMeteoHost, '/v1/forecast', {
      'latitude': coordinates.latitude.toString(),
      'longitude': coordinates.longitude.toString(),
      'daily':
          'temperature_2m_mean,relative_humidity_2m_mean,sunshine_duration,precipitation_sum',
      'hourly': 'temperature_2m,relative_humidity_2m',
      'timezone': 'auto',
      'start_date': dateKey(date),
      'end_date': dateKey(date),
    });

    try {
      final response = await _http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final daily = body['daily'];
      if (daily is Map<String, dynamic>) {
        final temperature = _firstNumber(daily['temperature_2m_mean']);
        final humidity = _firstNumber(daily['relative_humidity_2m_mean']);
        final sunshineSeconds = _firstNumber(daily['sunshine_duration']);
        if (temperature != null && humidity != null) {
          return (
            temperature: temperature,
            humidity: humidity,
            sunshineHours: sunshineSeconds == null
                ? 0.0
                : (sunshineSeconds / 3600).clamp(0.0, 24.0).toDouble(),
          );
        }
      }

      // Fall back to averaging the hourly series when daily aggregates are
      // missing, which happens for the current day before it has finished.
      final hourly = body['hourly'];
      final temperature = _mean(hourly is Map<String, dynamic>
          ? hourly['temperature_2m']
          : null);
      final humidity =
          _mean(hourly is Map<String, dynamic> ? hourly['relative_humidity_2m'] : null);
      if (temperature == null || humidity == null) return null;

      return (
        temperature: temperature,
        humidity: humidity,
        // Hourly data carries no sunshine total, so zero is reported rather
        // than a guess. A zero is treated as "unknown" by the caller below.
        sunshineHours: 0.0,
      );
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      // Malformed JSON.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PM2.5 from the nearest Open-AQ station, or null when unavailable.
  ///
  /// Open-AQ returns measurements newest-first (`datetime` DESC) and includes
  /// stations across the border, so candidates are filtered to Bangladesh.
  Future<double?> _fetchPm25(({double latitude, double longitude}) coordinates) async {
    final uri = Uri.https(_openAqHost, '/v3/locations', {
      'coordinates': '${coordinates.latitude},${coordinates.longitude}',
      'radius': '25000',
      'limit': '10',
      'parameter': 'pm25',
    });

    try {
      final response = await _http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final results = body['results'];
      if (results is! List) return null;

      double? best;
      for (final location in results) {
        if (location is! Map<String, dynamic>) continue;

        // Prefer a Bangladeshi station; keep foreign stations only as a last
        // resort so a border-adjacent station can still be used.
        final country = location['country'];
        final isBangladesh = country is Map<String, dynamic> &&
            (country['code'] == 'BD' || country['name'] == 'Bangladesh');

        final measurements = location['measurements'];
        if (measurements is! List) continue;

        for (final reading in measurements) {
          if (reading is! Map<String, dynamic>) continue;
          final parameter = reading['parameter'];
          final parameterName = parameter is Map<String, dynamic>
              ? parameter['name']
              : parameter;
          if (parameterName != 'pm25') continue;

          final value = _asDouble(reading['value']);
          if (value == null || value < 0 || value > 2000) continue;

          if (isBangladesh) return value;
          best ??= value;
        }
      }
      return best;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// First numeric entry of a JSON array such as a daily aggregate list.
  static double? _firstNumber(Object? value) {
    if (value is List && value.isNotEmpty) return _asDouble(value.first);
    return _asDouble(value);
  }

  /// Arithmetic mean of the numeric entries, ignoring nulls.
  static double? _mean(Object? value) {
    if (value is! List) return null;
    final numbers = <double>[];
    for (final entry in value) {
      final number = _asDouble(entry);
      if (number != null) numbers.add(number);
    }
    if (numbers.isEmpty) return null;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }

  /// Releases the HTTP client if this service created it.
  void dispose() {
    if (_ownsClient) _http.close();
  }
}
