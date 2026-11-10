import 'dart:io';

import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/consent_record.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v1 schema, reproduced exactly as it shipped.
///
/// Written out rather than imported so this test keeps working after the
/// production schema moves on: it is a record of what an old install actually
/// has on disk, and if it drifts with the current code it stops testing
/// anything.
const List<String> _v1Schema = [
  '''
  CREATE TABLE cycles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_date TEXT UNIQUE NOT NULL,
    duration INTEGER,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE climate_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT UNIQUE NOT NULL,
    temperature REAL,
    humidity REAL,
    heat_index REAL,
    sunshine_hours REAL,
    pm25 REAL,
    aqi_category TEXT,
    fetched_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  'CREATE INDEX idx_cycles_start_date ON cycles (start_date)',
  'CREATE INDEX idx_climate_date ON climate_cache (date)',
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('schema v2', () {
    late DatabaseHelper db;

    setUp(() async {
      db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
      await db.close();
    });

    tearDown(() async {
      await db.close();
      db.overridePath = null;
    });

    test('a fresh install gets the consent log', () async {
      final database = await db.database;
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      expect(names, contains(DatabaseHelper.consentTable));

      final columns = await database.rawQuery(
        'PRAGMA table_info(${DatabaseHelper.consentTable})',
      );
      expect(
        columns.map((c) => c['name']),
        ['id', 'action', 'method', 'recorded_at'],
      );
      // The log records what happened; it does not record who she is or what
      // the cycles were, so a revocation row survives a wipe harmlessly.
      expect(
        columns.map((c) => c['name']),
        isNot(contains('cycle')),
      );
    });

    test('a v1 database upgrades to v2 and keeps every cycle', () async {
      final dir = await Directory.systemTemp.createTemp('elara_migration');
      final path = p.join(dir.path, 'elara.db');

      // Build a real v1 database, exactly as the previous release left it.
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            for (final statement in _v1Schema) {
              await database.execute(statement);
            }
          },
        ),
      );
      for (final date in ['2026-01-01', '2026-01-29', '2026-02-27']) {
        await legacy.insert('cycles', {
          'start_date': date,
          'duration': 5,
          'created_at': '2026-03-01T00:00:00.000',
        });
      }
      await legacy.insert('settings', {'key': 'theme_mode', 'value': 'dark'});
      await legacy.close();

      // Now open it with the current build.
      db.overridePath = path;
      final upgraded = await db.database;

      expect(await upgraded.getVersion(), DatabaseHelper.schemaVersion);
      expect(await db.countCycles(), 3, reason: 'history must survive');
      expect(await db.getSetting('theme_mode'), 'dark',
          reason: 'settings must survive');

      final tables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(
        tables.map((row) => row['name']),
        contains(DatabaseHelper.consentTable),
      );

      // The heart of the upgrade rule: existing records are not consent.
      expect(
        await db.getConsentRecords(),
        isEmpty,
        reason: 'no consent row may be invented from existing cycles',
      );

      await dir.delete(recursive: true);
    });

    test('the upgrade is not re-run and cycles are not duplicated', () async {
      final dir = await Directory.systemTemp.createTemp('elara_migration2');
      final path = p.join(dir.path, 'elara.db');

      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            for (final statement in _v1Schema) {
              await database.execute(statement);
            }
          },
        ),
      );
      await legacy.insert('cycles', {
        'start_date': '2026-01-01',
        'duration': 5,
        'created_at': '2026-03-01T00:00:00.000',
      });
      await legacy.close();

      db.overridePath = path;
      await db.close();
      expect(await db.countCycles(), 1);

      // Reopen, as the app does on every launch.
      await db.close();
      expect(await db.countCycles(), 1);
      expect(await db.getConsentRecords(), isEmpty);

      await dir.delete(recursive: true);
    });
  });

  group('consent log', () {
    late DatabaseHelper db;

    setUp(() async {
      db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
      await db.close();
      await db.resetAllData();
    });

    tearDown(() async {
      await db.close();
      db.overridePath = null;
    });

    test('is empty on a fresh database', () async {
      expect(await db.getConsentRecords(), isEmpty);
      expect(await db.getLatestConsentRecord(), isNull);
    });

    test('appends rather than replaces', () async {
      await db.addConsentRecord(
        ConsentRecord(
          action: ConsentAction.granted,
          method: ConsentMethod.setup,
          recordedAt: DateTime(2026, 1, 1, 9),
        ),
      );
      await db.addConsentRecord(
        ConsentRecord(
          action: ConsentAction.revoked,
          method: ConsentMethod.settings,
          recordedAt: DateTime(2026, 2, 1, 9),
        ),
      );

      final all = await db.getConsentRecords();
      expect(all, hasLength(2));
      expect(all.first.action, ConsentAction.granted);
      expect(all.last.action, ConsentAction.revoked);

      final latest = await db.getLatestConsentRecord();
      expect(latest!.action, ConsentAction.revoked);
    });

    test('round-trips every action and method', () async {
      for (final action in ConsentAction.values) {
        for (final method in ConsentMethod.values) {
          await db.addConsentRecord(
            ConsentRecord(
              action: action,
              method: method,
              recordedAt: DateTime(2026, 3, 1),
            ),
          );
        }
      }
      final all = await db.getConsentRecords();
      expect(all, hasLength(ConsentAction.values.length * ConsentMethod.values.length));
      expect(all.map((r) => r.action).toSet(), ConsentAction.values.toSet());
      expect(all.map((r) => r.method).toSet(), ConsentMethod.values.toSet());
    });

    test('a full reset clears the log along with the data', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.addConsentRecord(
        ConsentRecord(
          action: ConsentAction.granted,
          method: ConsentMethod.setup,
          recordedAt: DateTime(2026, 1, 1),
        ),
      );

      await db.resetAllData();

      expect(await db.countCycles(), 0);
      expect(await db.getConsentRecords(), isEmpty);
    });

    test('replaceAllCycles is atomic and refuses duplicates', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));

      // A duplicate inside the batch must leave the previous history intact.
      await expectLater(
        db.replaceAllCycles([
          CycleEntry(startDate: DateTime(2026, 5, 1)),
          CycleEntry(startDate: DateTime(2026, 5, 1)),
        ]),
        throwsA(isA<DatabaseException>()),
      );

      final cycles = await db.getAllCycles();
      expect(cycles, hasLength(1));
      expect(cycles.single.startDate, DateTime(2026, 1, 1));
    });
  });
}
