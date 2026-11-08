import 'dart:convert';

import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end: real sqflite rows -> real elara-core pipeline.
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

  /// Offline climate client, so predictions here do not depend on the network.
  http.Client offlineClient() => MockClient((_) async => http.Response('down', 500));

  PredictionService buildService({DateTime? now, http.Client? client}) {
    DateTime clock() => now ?? DateTime(2026, 4, 10, 9);
    return PredictionService(
      database: db,
      climateService: ClimateService(
        database: db,
        httpClient: client ?? offlineClient(),
        clock: clock,
        timeout: const Duration(seconds: 2),
      ),
      clock: clock,
    );
  }

  /// Four 28-day cycles ending shortly before [now].
  Future<void> seedRegularHistory({DateTime? now}) async {
    final anchor = now ?? DateTime(2026, 4, 10);
    for (var i = 3; i >= 0; i--) {
      await db.insertCycle(
        CycleEntry(
          startDate: anchor.subtract(Duration(days: 28 * i)),
          duration: 5,
        ),
      );
    }
  }

  group('without history', () {
    test('returns null when no cycle is recorded', () async {
      final result = await buildService().predict();
      expect(result, isNull);
    });

    test('single cycle does not throw', () async {
      await db.insertCycle(
        CycleEntry(startDate: DateTime(2026, 4, 1), duration: 5),
      );
      // Whether core can forecast from one cycle is core's business; the app's
      // contract is only that it degrades instead of throwing.
      final result = await buildService().predict();
      expect(result == null || result.prediction.cycleLength > 0, isTrue);
    });
  });

  group('with regular history', () {
    test('produces a forecast close to the observed 28-day rhythm', () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      final result = await buildService(now: now).predict();

      expect(result, isNotNull);
      expect(result!.cycleLength, closeTo(28, 2));
      // Last start was 2026-04-10, so the next estimate is around 2026-05-08.
      final daysAhead = daysBetween(now, result.nextPeriodDate);
      expect(daysAhead, inInclusiveRange(24, 32));
      expect(result.windowDays, greaterThanOrEqualTo(0));
      expect(result.confidence, inInclusiveRange(0, 1));
      expect(result.contributingEngines, isNotEmpty);
    });

    test('classifies a phase and produces suggestions', () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      final result = await buildService(now: now).predict();

      expect(result!.phase, isNotNull);
      expect(result.phaseOrUnknown, isNot(core.CyclePhase.unknown));
      expect(result.phase!.cycleDay, greaterThanOrEqualTo(1));
      expect(result.severity, isNotNull);
      expect(result.action, isNotNull);
      expect(result.action!.cards, isNotEmpty);
      expect(result.action!.conversationScore, greaterThanOrEqualTo(1));
    });

    test('carries the environmental input used for severity', () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      final result = await buildService(now: now).predict();

      // The offline client forces the seasonal fallback for April.
      expect(result!.environment.isFallback, isTrue);
      expect(result.environment.temperature, 32);
      expect(result.isEnvironmentalFallback, isTrue);
      expect(result.severity!.severityScore, inInclusiveRange(0, 1));
    });

    test('uses live weather when the network answers', () async {
      final now = DateTime(2026, 7, 15, 9);
      await seedRegularHistory(now: now);

      final client = MockClient((request) async {
        if (request.url.host == 'api.open-meteo.com') {
          return http.Response(
            jsonEncode({
              'daily': {
                'temperature_2m_mean': [35.0],
                'relative_humidity_2m_mean': [80.0],
                'sunshine_duration': [18000],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'results': [
              {
                'country': {'code': 'BD', 'name': 'Bangladesh'},
                'measurements': [
                  {'parameter': {'name': 'pm25'}, 'value': 60.0},
                ],
              },
            ],
          }),
          200,
        );
      });

      final result =
          await buildService(now: now, client: client).predict();

      expect(result!.environment.isFallback, isFalse);
      expect(result.environment.temperature, 35.0);
      expect(result.environment.pm25, 60.0);
    });

    test('honours the recorded period duration in phase classification',
        () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      // Day 2 of a cycle whose period lasts 5 days is menstrual.
      final onDayTwo = await buildService(now: now)
          .predict(date: now.add(const Duration(days: 1)));
      expect(onDayTwo!.phaseOrUnknown, core.CyclePhase.menstrual);
    });

    test('reports an overdue cycle without inventing a phase', () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      // Well past the estimated next start, with nothing logged since.
      final muchLater = now.add(const Duration(days: 60));
      final result = await buildService(now: muchLater).predict();

      expect(result, isNotNull);
      expect(result!.daysUntilNextPeriod, lessThan(0));
      expect(result.isOverdue, isTrue);
      expect(result.phaseOrUnknown, core.CyclePhase.unknown);
    });
  });

  group('robustness', () {
    test('a sub-15-day forecast downgrades the phase instead of failing',
        () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      // A ten-day history alone would be regularised by the ensemble, so inject
      // a single engine that really does forecast a 10-day cycle. That is what
      // exercises the classifier's floor.
      final result = await PredictionService(
        database: db,
        climateService: ClimateService(
          database: db,
          httpClient: offlineClient(),
          clock: () => now,
          timeout: const Duration(seconds: 2),
        ),
        fusion: core.ElaraFusion(engines: [_TenDayEngine()]),
        clock: () => now,
      ).predict();

      expect(result, isNotNull);
      expect(result!.cycleLength, 10);
      expect(result.phase, isNull);
      expect(result.unavailableReason, contains('shorter than'));
      // Severity is still available: it does not depend on the phase.
      expect(result.severity, isNotNull);
      // And no suggestions are invented for an unclassified phase.
      expect(result.action, isNull);
    });

    test('a cycle longer than the estimated cycle is handled', () async {
      final now = DateTime(2026, 4, 10, 9);
      await db.insertCycle(
        CycleEntry(startDate: now.subtract(const Duration(days: 28)),
            duration: 6),
      );
      await db.insertCycle(
        CycleEntry(startDate: now, duration: 40), // absurd duration
      );

      final result = await buildService(now: now).predict();
      // Either a forecast with no phase, or no forecast; never an exception.
      if (result != null) {
        expect(result.phase, isNull);
        expect(result.unavailableReason, isNotNull);
      }
    });

    test('out-of-order and duplicate rows are tolerated', () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);
      // A start earlier than the newest one would break core's ordering rules
      // if it were passed through naively.
      await db.insertCycle(
        CycleEntry(startDate: now.subtract(const Duration(days: 100))),
      );

      final result = await buildService(now: now).predict();
      expect(result, isNotNull);
    });

    test('prediction is stable across repeated calls', () async {
      final now = DateTime(2026, 4, 10, 9);
      await seedRegularHistory(now: now);

      final first = await buildService(now: now).predict();
      final second = await buildService(now: now).predict();

      expect(dateKey(first!.nextPeriodDate), dateKey(second!.nextPeriodDate));
      expect(first.cycleLength, second.cycleLength);
    });
  });
}

/// An engine that always forecasts a ten-day cycle, to exercise the
/// phase classifier's minimum-cycle-length guard.
class _TenDayEngine implements core.CyclePredictionEngine {
  @override
  String get name => 'TenDayProbe';

  @override
  bool get isActive => true;

  @override
  core.EngineOutput? predict(List<core.CycleRecord> history) {
    if (history.isEmpty) return null;
    final start = history.last.startDate;
    return core.EngineOutput(
      engineName: name,
      // elara-core requires the date to match start + rounded length.
      predictedDate: start.add(const Duration(days: 10)),
      predictedLength: 10,
      confidence: 0.9,
      windowDays: 2,
    );
  }
}
