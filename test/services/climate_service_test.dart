import 'dart:convert';
import 'dart:io';

import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/models/climate_snapshot.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Open-Meteo daily payload for a hot, humid Dhaka day.
String openMeteoBody({
  double temperature = 33.4,
  double humidity = 78,
  double sunshineSeconds = 23400, // 6.5 hours
}) =>
    jsonEncode({
      'latitude': 23.81,
      'longitude': 90.41,
      'daily': {
        'time': ['2026-06-15'],
        'temperature_2m_mean': [temperature],
        'relative_humidity_2m_mean': [humidity],
        'sunshine_duration': [sunshineSeconds],
        'precipitation_sum': [0.0],
      },
    });

String openAqBody({double pm25 = 47.5, String countryCode = 'BD'}) => jsonEncode({
      'results': [
        {
          'country': {'code': countryCode, 'name': 'Bangladesh'},
          'measurements': [
            {'parameter': {'name': 'pm25'}, 'value': pm25},
          ],
        },
      ],
    });

/// Builds a client that answers by host, and records what was requested.
MockClient mockNetwork({
  List<Uri>? calls,
  String? meteoBody,
  String? aqBody,
  int meteoStatus = 200,
  int aqStatus = 200,
}) {
  return MockClient((request) async {
    calls?.add(request.url);
    if (request.url.host == 'api.open-meteo.com') {
      if (meteoStatus != 200) return http.Response('error', meteoStatus);
      return http.Response(meteoBody ?? openMeteoBody(), 200);
    }
    if (request.url.host == 'api.openaq.org') {
      if (aqStatus != 200) return http.Response('error', aqStatus);
      return http.Response(aqBody ?? openAqBody(), 200);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  late DatabaseHelper db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance;
    db.overridePath = inMemoryDatabasePath;
    await db.close();
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  final fixedNow = DateTime(2026, 6, 15, 10);

  ClimateService serviceWith(
    http.Client client, {
    DateTime? now,
  }) =>
      ClimateService(
        database: db,
        httpClient: client,
        clock: () => now ?? fixedNow,
        timeout: const Duration(seconds: 2),
      );

  group('live fetch', () {
    test('uses Open-Meteo values and caches them', () async {
      final service = serviceWith(mockNetwork());
      final snapshot = await service.getTodayClimate();

      expect(snapshot.temperature, 33.4);
      expect(snapshot.humidity, 78);
      // 23400 seconds -> 6.5 hours.
      expect(snapshot.sunshineHours, 6.5);
      expect(snapshot.pm25, 47.5);
      // 47.5 falls in the 35.5-55.4 band, not "Unhealthy".
      expect(snapshot.aqiCategory, 'Unhealthy for Sensitive Groups');
      expect(snapshot.isFallback, isFalse);

      final cached = await db.getClimateFor(fixedNow);
      expect(cached, isNotNull);
      expect(cached!.temperature, 33.4);
      expect(dateKey(cached.date), '2026-06-15');
    });

    test('computes a heat index above the air temperature', () async {
      final service = serviceWith(mockNetwork());
      final snapshot = await service.getTodayClimate();

      expect(snapshot.heatIndex, greaterThan(snapshot.temperature));
      // Steadman for 33.4C / 78% RH is around 41C.
      expect(snapshot.heatIndex, closeTo(41.0, 1.5));
    });

    test('requests the stored coordinates, not hardcoded ones', () async {
      await db.setSettings({'latitude': '22.3', 'longitude': '91.8'});
      final calls = <Uri>[];
      final service = serviceWith(mockNetwork(calls: calls));

      await service.getTodayClimate();

      final meteo = calls.firstWhere((u) => u.host == 'api.open-meteo.com');
      expect(meteo.queryParameters['latitude'], '22.3');
      expect(meteo.queryParameters['longitude'], '91.8');
      expect(meteo.queryParameters['start_date'], '2026-06-15');
    });

    test('falls back to the hourly series when daily aggregates are absent',
        () async {
      final body = jsonEncode({
        'hourly': {
          'temperature_2m': [30.0, 32.0],
          'relative_humidity_2m': [70.0, 80.0],
        },
      });
      final service = serviceWith(mockNetwork(meteoBody: body));
      final snapshot = await service.getTodayClimate();

      expect(snapshot.temperature, 31.0);
      expect(snapshot.humidity, 75.0);
      expect(snapshot.sunshineHours, 0.0);
    });
  });

  group('cache', () {
    test('a second call inside three hours does not hit the network', () async {
      final calls = <Uri>[];
      final service = serviceWith(mockNetwork(calls: calls));

      await service.getTodayClimate();
      final firstCallCount = calls.length;
      await service.getTodayClimate();

      expect(calls.length, firstCallCount,
          reason: 'the cached snapshot should have been reused');
    });

    test('a call after three hours refetches', () async {
      final first = mockNetwork();
      await serviceWith(first).getTodayClimate();

      final calls = <Uri>[];
      final later = fixedNow.add(const Duration(hours: 3, minutes: 1));
      await serviceWith(mockNetwork(calls: calls), now: later).getTodayClimate();

      expect(calls, isNotEmpty);
    });

    test('a fallback is not cached, so a later live call replaces it',
        () async {
      await serviceWith(
        mockNetwork(meteoStatus: 500, aqStatus: 500),
      ).getTodayClimate();

      expect(await db.getClimateFor(fixedNow), isNull);

      final calls = <Uri>[];
      await serviceWith(mockNetwork(calls: calls)).getTodayClimate();
      expect(calls, isNotEmpty);
    });
  });

  group('never throws, always returns a value', () {
    Future<ClimateSnapshot> run(http.Client client) async {
      final service = serviceWith(client);
      // The contract under test: this never throws.
      return service.getTodayClimate();
    }

    test('server error on both APIs', () async {
      final snapshot =
          await run(mockNetwork(meteoStatus: 500, aqStatus: 503));
      expect(snapshot.isFallback, isTrue);
      expect(snapshot.temperature, 29); // June is monsoon
    });

    test('socket failure', () async {
      final snapshot = await run(MockClient((_) async {
        throw const SocketException('no route to host');
      }));
      expect(snapshot.isFallback, isTrue);
      expect(snapshot.temperature, 29);
    });

    test('client failure', () async {
      final snapshot = await run(MockClient((_) async {
        throw http.ClientException('connection closed');
      }));
      expect(snapshot.isFallback, isTrue);
    });

    test('malformed JSON', () async {
      final snapshot = await run(mockNetwork(meteoBody: '<html>oops</html>'));
      expect(snapshot.isFallback, isTrue);
    });

    test('JSON of the wrong shape', () async {
      final snapshot = await run(mockNetwork(meteoBody: '[1,2,3]'));
      expect(snapshot.isFallback, isTrue);
    });

    test('timeout', () async {
      final snapshot = await run(MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return http.Response('{}', 200);
      }));
      expect(snapshot.isFallback, isTrue);
    });
  });

  group('PM2.5', () {
    test('uses the seasonal value when Open-AQ fails', () async {
      final service = serviceWith(mockNetwork(aqStatus: 500));
      final snapshot = await service.getTodayClimate();

      // Weather was live, so temperature is real but PM2.5 is not.
      expect(snapshot.temperature, 33.4);
      expect(snapshot.pm25, 35); // June monsoon baseline
      expect(snapshot.isFallback, isTrue,
          reason: 'partially estimated data must not claim to be live');
    });

    test('prefers a Bangladeshi station over a foreign one', () async {
      final body = jsonEncode({
        'results': [
          {
            'country': {'code': 'IN', 'name': 'India'},
            'measurements': [
              {'parameter': {'name': 'pm25'}, 'value': 12.0},
            ],
          },
          {
            'country': {'code': 'BD', 'name': 'Bangladesh'},
            'measurements': [
              {'parameter': {'name': 'pm25'}, 'value': 88.0},
            ],
          },
        ],
      });
      final service = serviceWith(mockNetwork(aqBody: body));
      final snapshot = await service.getTodayClimate();

      expect(snapshot.pm25, 88.0);
      expect(snapshot.aqiCategory, 'Unhealthy');
    });

    test('ignores non-pm25 and out-of-range measurements', () async {
      final body = jsonEncode({
        'results': [
          {
            'country': {'code': 'BD', 'name': 'Bangladesh'},
            'measurements': [
              {'parameter': {'name': 'pm10'}, 'value': 300.0},
              {'parameter': {'name': 'pm25'}, 'value': -5.0},
              {'parameter': {'name': 'pm25'}, 'value': 99999.0},
            ],
          },
        ],
      });
      final service = serviceWith(mockNetwork(aqBody: body));
      final snapshot = await service.getTodayClimate();

      // Nothing usable, so the seasonal PM2.5 is used.
      expect(snapshot.pm25, 35);
    });
  });

  group('seasonal fallback values', () {
    ClimateSnapshot fallbackFor(int month) =>
        ClimateSnapshot.seasonalFallback(DateTime(2026, month, 15));

    test('December-February is winter', () {
      for (final month in [12, 1, 2]) {
        final snapshot = fallbackFor(month);
        expect(snapshot.temperature, 18, reason: 'month $month');
        expect(snapshot.humidity, 65);
        expect(snapshot.sunshineHours, 7.5);
        expect(snapshot.pm25, 80);
        expect(snapshot.seasonNote, 'Winter');
      }
    });

    test('March-May is pre-monsoon', () {
      for (final month in [3, 4, 5]) {
        final snapshot = fallbackFor(month);
        expect(snapshot.temperature, 32, reason: 'month $month');
        expect(snapshot.humidity, 75);
        expect(snapshot.sunshineHours, 6);
        expect(snapshot.pm25, 60);
        expect(snapshot.seasonNote, 'Pre-monsoon');
      }
    });

    test('June-September is monsoon', () {
      for (final month in [6, 7, 8, 9]) {
        final snapshot = fallbackFor(month);
        expect(snapshot.temperature, 29, reason: 'month $month');
        expect(snapshot.humidity, 90);
        expect(snapshot.sunshineHours, 3.5);
        expect(snapshot.pm25, 35);
        expect(snapshot.seasonNote, 'Monsoon');
      }
    });

    test('October-November is post-monsoon', () {
      for (final month in [10, 11]) {
        final snapshot = fallbackFor(month);
        expect(snapshot.temperature, 26, reason: 'month $month');
        expect(snapshot.humidity, 78);
        expect(snapshot.sunshineHours, 7);
        expect(snapshot.pm25, 50);
        expect(snapshot.seasonNote, 'Post-monsoon');
      }
    });

    test('mapping to elara-core stays inside the values core accepts', () {
      final snapshot = fallbackFor(7);
      final conditions = snapshot.toEnvironmentConditions();
      expect(conditions.aqiCategory, inInclusiveRange(1, 5));
      expect(conditions.hydrationLevel, inInclusiveRange(1, 3));
      expect(conditions.sunshineHours, inInclusiveRange(0, 24));
    });
  });
}
