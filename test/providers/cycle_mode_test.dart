import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/data/models/cycle_mode.dart';
import 'package:elara_app/providers/settings_keys.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Whether the app is allowed to predict, and what happens to everything else
/// when it is not.
///
/// The mode is not a cosmetic switch. It decides whether a phase, a countdown
/// and a fertile window appear on the Today screen, in the calendar, on the day
/// sheet and inside the notification schedule — all of which read the one
/// service gated here. These tests exist because the failure mode is not a
/// crash: it is a confident, wrong date shown to a woman on the pill.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late SettingsProvider settings;
  late PredictionService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
    await db.close();
    await db.resetAllData();
    settings = SettingsProvider(database: db);
    await settings.load();
    service = PredictionService(
      database: db,
      climateService: ClimateService(
        database: db,
        httpClient: MockClient((_) async => http.Response('', 503)),
      ),
    );

    // A history with enough in it to produce a forecast.
    final now = DateTime(2026, 11, 1);
    for (final back in [56, 28]) {
      await db.insertCycle(
        CycleEntry(startDate: now.subtract(Duration(days: back)), duration: 5),
      );
    }
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  test('a fresh install predicts, so nothing changes for existing users',
      () async {
    expect(settings.cycleMode, CycleMode.predicting);
    expect(settings.cycleMode.predicts, isTrue);
    final result = await service.predict(date: DateTime(2026, 11, 2));
    expect(result, isNotNull);
    expect(result!.prediction.cycleLength, greaterThan(0));
  });

  test('hormonal contraception stops the forecast at the service', () async {
    await settings.setCycleMode(CycleMode.hormonalContraception);

    expect(await service.isPredicting(), isFalse);
    // The one gate every screen and the reminder scheduler pass through.
    expect(await service.predict(date: DateTime(2026, 11, 2)), isNull);
  });

  test('a pause stops the forecast and keeps the recorded history', () async {
    await settings.setCycleMode(
      CycleMode.paused,
      reason: PauseReason.loss,
      since: DateTime(2026, 11, 3),
    );

    expect(settings.cycleMode, CycleMode.paused);
    expect(settings.pauseReason, PauseReason.loss);
    expect(settings.pauseSince, DateTime(2026, 11, 3));
    expect(await service.predict(date: DateTime(2026, 11, 2)), isNull);

    // Nothing was deleted: the dates she recorded are still hers, and still
    // there when prediction comes back.
    final cycles = await db.getAllCycles();
    expect(cycles, hasLength(2));
  });

  test('resuming predicts again and clears the pause wording', () async {
    await settings.setCycleMode(
      CycleMode.paused,
      reason: PauseReason.pregnancy,
    );
    expect(await settings.setCycleMode(CycleMode.predicting), isTrue);

    expect(settings.cycleMode, CycleMode.predicting);
    // A stale reason displayed after a resume would be a sentence about her
    // body that is no longer true.
    expect(settings.pauseReason, isNull);
    expect(settings.pauseSince, isNull);
    expect(await service.predict(date: DateTime(2026, 11, 2)), isNotNull);
  });

  test('changing only the reason keeps the day the pause began', () async {
    await settings.setCycleMode(
      CycleMode.paused,
      reason: PauseReason.other,
      since: DateTime(2026, 10, 20),
    );
    await settings.setCycleMode(
      CycleMode.paused,
      reason: PauseReason.postpartum,
      since: settings.pauseSince,
    );

    expect(settings.pauseReason, PauseReason.postpartum);
    expect(settings.pauseSince, DateTime(2026, 10, 20));
  });

  test('a stored mode the app cannot read fails quiet, not loud', () async {
    // A future version writing a mode this build has never heard of must not
    // produce confident forecasts. Silence is the safe failure for a claim
    // about a body.
    await db.setSetting(SettingsKeys.cycleMode, 'some_future_mode');
    await settings.load();

    expect(settings.cycleMode, CycleMode.paused);
    expect(await service.predict(date: DateTime(2026, 11, 2)), isNull);
  });

  test('the mode survives a restart', () async {
    await settings.setCycleMode(CycleMode.hormonalContraception);

    final reopened = SettingsProvider(database: db);
    await reopened.load();

    expect(reopened.cycleMode, CycleMode.hormonalContraception);
    expect(await service.predict(date: DateTime(2026, 11, 2)), isNull);
  });

  test('a failed write leaves the previous mode in place', () async {
    await settings.setCycleMode(CycleMode.hormonalContraception);
    // Point the database at a directory that does not exist, so opening it
    // throws rather than silently creating a new one.
    await db.close();
    db.overridePath = '/nonexistent-elara-test/x.db';

    final ok = await settings.setCycleMode(CycleMode.predicting);

    expect(ok, isFalse);
    // The in-memory value is not changed either: a screen must never show a
    // preference that was not saved.
    expect(settings.cycleMode, CycleMode.hormonalContraception);
    expect(settings.lastError, isNotNull);
  });
}
