import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/consent_record.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/consent_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The consent state machine, against the real schema.
///
/// These tests exist because the interesting failures here are not crashes.
/// They are quiet ones: an install that is treated as consented because dates
/// happened to be present, a revocation that logs itself before wiping, a grant
/// that is lost on restart. Each has a test below.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late ConsentProvider consent;

  setUp(() async {
    db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
    await db.close();
    await db.resetAllData();
    consent = ConsentProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  group('first run', () {
    test('is notAsked and needs the gate', () async {
      await consent.load();
      expect(consent.state, ConsentState.notAsked);
      expect(consent.hasConsent, isFalse);
      expect(consent.needsGate, isTrue);
    });

    test('granting opens the app and is persisted', () async {
      await consent.load();
      expect(await consent.grant(method: ConsentMethod.setup), isTrue);

      expect(consent.state, ConsentState.granted);
      expect(consent.hasConsent, isTrue);

      // A fresh provider, as after a restart, reads the same conclusion.
      final reopened = ConsentProvider(database: db);
      await reopened.load();
      expect(reopened.state, ConsentState.granted);
      expect(reopened.latest!.action, ConsentAction.granted);
      expect(reopened.latest!.method, ConsentMethod.setup);
    });

    test('granting records when it happened', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await consent.load();
      await consent.grant(method: ConsentMethod.setup);
      final after = DateTime.now().add(const Duration(seconds: 1));

      final at = consent.latest!.recordedAt;
      expect(at.isAfter(before), isTrue);
      expect(at.isBefore(after), isTrue);
    });
  });

  group('upgrade from a build without consent', () {
    setUp(() async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 29)));
    });

    test('existing records alone never count as consent', () async {
      await consent.load();
      expect(consent.state, ConsentState.legacyAcknowledgementDue);
      expect(consent.hasConsent, isFalse);
      expect(consent.needsGate, isTrue);

      // And nothing was written on the user's behalf.
      expect(await db.getConsentRecords(), isEmpty);
    });

    test('acknowledging keeps the records and is logged as an acknowledgement',
        () async {
      await consent.load();
      expect(await consent.acknowledgeLegacy(method: ConsentMethod.upgrade),
          isTrue);

      expect(consent.state, ConsentState.granted);
      expect(consent.latest!.action, ConsentAction.acknowledgedLegacy,
          reason: 'it must not be laundered into a grant');
      expect(consent.latest!.method, ConsentMethod.upgrade);

      // The history is untouched.
      expect(await db.countCycles(), 2);
    });

    test('acknowledging survives a restart', () async {
      await consent.load();
      await consent.acknowledgeLegacy(method: ConsentMethod.upgrade);

      final reopened = ConsentProvider(database: db);
      await reopened.load();
      expect(reopened.state, ConsentState.granted);
      expect(reopened.latest!.action, ConsentAction.acknowledgedLegacy);
    });

    test('declining deletes the records', () async {
      await consent.load();
      expect(await consent.revoke(), isTrue);

      expect(consent.state, ConsentState.revoked);
      expect(await db.countCycles(), 0);
      expect(consent.latest!.action, ConsentAction.revoked);
    });
  });

  group('revocation', () {
    setUp(() async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.setSetting('latitude', '51.5');
      await consent.load();
      await consent.grant(method: ConsentMethod.setup);
    });

    test('deletes the cycles and the settings', () async {
      expect(await consent.revoke(), isTrue);

      expect(await db.countCycles(), 0,
          reason: 'the health data it referred to must be gone');
      // Settings go too: a saved location is part of what was handed over.
      expect(await db.getSetting('latitude'), isNot('51.5'));
    });

    test('leaves a record that a withdrawal happened', () async {
      await consent.revoke();
      final records = await db.getConsentRecords();

      expect(records, hasLength(1));
      expect(records.single.action, ConsentAction.revoked);
      expect(records.single.method, ConsentMethod.settings);
    });

    test('closes the gate again', () async {
      await consent.revoke();
      expect(consent.hasConsent, isFalse);
      expect(consent.needsGate, isTrue);

      final reopened = ConsentProvider(database: db);
      await reopened.load();
      expect(reopened.state, ConsentState.revoked);
    });

    test('consent can be granted again afterwards', () async {
      await consent.revoke();
      expect(await consent.grant(method: ConsentMethod.setup), isTrue);
      expect(consent.state, ConsentState.granted);

      // The log keeps both events rather than overwriting.
      final records = await db.getConsentRecords();
      expect(records.map((r) => r.action),
          [ConsentAction.revoked, ConsentAction.granted]);
    });
  });

  group('robustness', () {
    test('a database failure leaves the gate closed rather than open',
        () async {
      // A path that cannot be opened: the provider must not decide that consent
      // exists just because it could not read the log.
      db.overridePath = '/nonexistent-directory/elara.db';
      await db.close();
      final broken = ConsentProvider(database: db);
      await broken.load();

      expect(broken.state, ConsentState.unknown);
      expect(broken.hasConsent, isFalse);
      expect(broken.lastError, isNotNull);
    });

    test('a failed write does not flip the state', () async {
      await consent.load();
      db.overridePath = '/nonexistent-directory/elara.db';
      await db.close();

      final ok = await consent.grant(method: ConsentMethod.setup);
      expect(ok, isFalse);
      expect(consent.state, ConsentState.notAsked);
      expect(consent.lastError, isNotNull);
    });
  });
}
