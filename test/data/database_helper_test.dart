import 'dart:io';

import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/models/climate_snapshot.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real schema and every CRUD path against a native sqlite3,
/// in memory. If this passes, the SQL that ships is the SQL that was tested.
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

  group('schema', () {
    test('creates the three tables from a cold start', () async {
      final database = await db.database;
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        'ORDER BY name',
      );
      final names = tables.map((row) => row['name']).toSet();
      expect(names, containsAll(<String>{'cycles', 'climate_cache', 'settings'}));
    });

    test('cycles has the exact specified columns', () async {
      final database = await db.database;
      final info = await database.rawQuery('PRAGMA table_info(cycles)');
      final columns = {
        for (final row in info)
          row['name'] as String: (
            type: row['type'] as String,
            notNull: (row['notnull'] as int) == 1,
            primaryKey: (row['pk'] as int) == 1,
          ),
      };
      expect(columns.keys,
          ['id', 'start_date', 'duration', 'created_at']);
      expect(columns['id']!.primaryKey, isTrue);
      expect(columns['start_date']!.notNull, isTrue);
      // duration is the one nullable column in cycles.
      expect(columns['duration']!.notNull, isFalse);
      expect(columns['created_at']!.notNull, isTrue);
    });

    test('climate_cache has the exact specified columns', () async {
      final database = await db.database;
      final info = await database.rawQuery('PRAGMA table_info(climate_cache)');
      final columns = [for (final row in info) row['name'] as String];
      expect(columns, [
        'id',
        'date',
        'temperature',
        'humidity',
        'heat_index',
        'sunshine_hours',
        'pm25',
        'aqi_category',
        'fetched_at',
      ]);
    });

    test('settings is a key/value table with key as primary key', () async {
      final database = await db.database;
      final info = await database.rawQuery('PRAGMA table_info(settings)');
      final rows = {
        for (final row in info) row['name'] as String: row,
      };
      expect(rows.keys, ['key', 'value']);
      expect(rows['key']!['pk'], 1);
      expect(rows['value']!['notnull'], 1);
    });

    test('reports the current schema version', () async {
      final database = await db.database;
      // Asserted against the constant, not a literal, so adding a migration
      // does not require editing a test that is only about the number.
      expect(await database.getVersion(), DatabaseHelper.schemaVersion);
      expect(DatabaseHelper.schemaVersion, greaterThanOrEqualTo(2));
    });
  });

  group('cycles CRUD', () {
    test('starts empty', () async {
      expect(await db.getAllCycles(), isEmpty);
      expect(await db.countCycles(), 0);
      expect(await db.getLatestCycle(), isNull);
    });

    test('inserts and reads back a cycle with an assigned id', () async {
      final stored = await db.insertCycle(
        CycleEntry(startDate: DateTime(2026, 1, 1), duration: 5),
      );
      expect(stored.id, isNotNull);
      expect(stored.duration, 5);

      final fetched = await db.getCycleById(stored.id!);
      expect(fetched, isNotNull);
      expect(fetched!.startDate, DateTime(2026, 1, 1));
      expect(fetched.duration, 5);
    });

    test('a cycle with no duration round-trips as null, not zero', () async {
      final stored =
          await db.insertCycle(CycleEntry(startDate: DateTime(2026, 2, 1)));
      final fetched = await db.getCycleById(stored.id!);
      expect(fetched!.duration, isNull);
    });

    test('rejects a duplicate start date (UNIQUE constraint)', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      expect(
        () => db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1))),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('upsert on the same date updates instead of duplicating', () async {
      await db.upsertCycle(
        CycleEntry(startDate: DateTime(2026, 1, 1), duration: 3),
      );
      await db.upsertCycle(
        CycleEntry(startDate: DateTime(2026, 1, 1), duration: 6),
      );
      final all = await db.getAllCycles();
      expect(all, hasLength(1));
      expect(all.single.duration, 6);
    });

    test('returns cycles oldest first regardless of insert order', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 3, 1)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 2, 1)));
      final all = await db.getAllCycles();
      expect(
        all.map((c) => dateKey(c.startDate)),
        ['2026-01-01', '2026-02-01', '2026-03-01'],
      );
    });

    test('latest cycle is the newest start date', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 3, 1)));
      final latest = await db.getLatestCycle();
      expect(latest!.startDate, DateTime(2026, 3, 1));
    });

    test('updates a cycle', () async {
      final stored =
          await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      final affected = await db.updateCycle(
        stored.copyWith(duration: 4),
      );
      expect(affected, 1);
      final fetched = await db.getCycleById(stored.id!);
      expect(fetched!.duration, 4);
    });

    test('update without an id is rejected', () async {
      expect(
        () => db.updateCycle(CycleEntry(startDate: DateTime(2026, 1, 1))),
        throwsArgumentError,
      );
    });

    test('deletes by id and by start date', () async {
      final a = await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 2, 1)));

      expect(await db.deleteCycle(a.id!), 1);
      expect(await db.countCycles(), 1);

      expect(await db.deleteCycleByStartDate(DateTime(2026, 2, 1)), 1);
      expect(await db.countCycles(), 0);
    });

    test('finds a cycle by start date', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 5, 4)));
      final found = await db.getCycleByStartDate(DateTime(2026, 5, 4, 13, 45));
      expect(found, isNotNull);
      expect(dateKey(found!.startDate), '2026-05-04');
    });

    test('computes completed cycle lengths', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 29)));
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 2, 27)));
      expect(await db.getCompletedCycleLengths(), [28, 29]);
    });

    test('a single cycle yields no completed lengths', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      expect(await db.getCompletedCycleLengths(), isEmpty);
    });
  });

  group('climate_cache CRUD', () {
    ClimateSnapshot sample(DateTime date, {DateTime? fetchedAt}) =>
        ClimateSnapshot(
          date: date,
          temperature: 31.5,
          humidity: 74,
          heatIndex: 38.2,
          sunshineHours: 6.5,
          pm25: 62,
          aqiCategory: ClimateSnapshot.aqiCategoryFor(62),
          fetchedAt: fetchedAt ?? DateTime(2026, 6, 1, 9),
        );

    test('round-trips every field', () async {
      final stored = await db.upsertClimate(sample(DateTime(2026, 6, 1)));
      expect(stored.id, isNotNull);

      final fetched = await db.getClimateFor(DateTime(2026, 6, 1));
      expect(fetched!.temperature, 31.5);
      expect(fetched.humidity, 74);
      expect(fetched.heatIndex, 38.2);
      expect(fetched.sunshineHours, 6.5);
      expect(fetched.pm25, 62);
      expect(fetched.aqiCategory, 'Unhealthy');
      expect(fetched.fetchedAt, DateTime(2026, 6, 1, 9));
    });

    test('upsert replaces the row for the same date', () async {
      await db.upsertClimate(sample(DateTime(2026, 6, 1)));
      await db.upsertClimate(ClimateSnapshot(
        date: DateTime(2026, 6, 1),
        temperature: 20,
        humidity: 50,
        heatIndex: 20,
        sunshineHours: 1,
        pm25: 10,
        aqiCategory: 'Good',
        fetchedAt: DateTime(2026, 6, 1, 12),
      ));
      final all = await db.getAllClimateSnapshots();
      expect(all, hasLength(1));
      expect(all.single.temperature, 20);
    });

    test('fresh cache is returned only inside the three-hour window', () async {
      final now = DateTime(2026, 6, 1, 12);
      await db.upsertClimate(sample(DateTime(2026, 6, 1), fetchedAt: now));

      expect(await db.getFreshClimateFor(DateTime(2026, 6, 1), now: now),
          isNotNull);
      // 2h59m old: still fresh.
      expect(
        await db.getFreshClimateFor(
          DateTime(2026, 6, 1),
          now: now.add(const Duration(hours: 2, minutes: 59)),
        ),
        isNotNull,
      );
      // 3h01m old: stale.
      expect(
        await db.getFreshClimateFor(
          DateTime(2026, 6, 1),
          now: now.add(const Duration(hours: 3, minutes: 1)),
        ),
        isNull,
      );
    });

    test('a fetched_at in the future is treated as stale', () async {
      final now = DateTime(2026, 6, 1, 12);
      await db.upsertClimate(
        sample(DateTime(2026, 6, 1), fetchedAt: now.add(const Duration(hours: 5))),
      );
      expect(await db.getFreshClimateFor(DateTime(2026, 6, 1), now: now), isNull);
    });

    test('prunes rows older than a cutoff', () async {
      await db.upsertClimate(sample(DateTime(2026, 5, 1)));
      await db.upsertClimate(sample(DateTime(2026, 6, 1)));
      final removed = await db.pruneClimateBefore(DateTime(2026, 5, 15));
      expect(removed, 1);
      final remaining = await db.getAllClimateSnapshots();
      expect(remaining, hasLength(1));
      expect(dateKey(remaining.single.date), '2026-06-01');
    });

    test('deletes a single day and everything', () async {
      await db.upsertClimate(sample(DateTime(2026, 5, 1)));
      await db.upsertClimate(sample(DateTime(2026, 6, 1)));
      expect(await db.deleteClimateFor(DateTime(2026, 5, 1)), 1);
      expect(await db.deleteAllClimate(), 1);
      expect(await db.getAllClimateSnapshots(), isEmpty);
    });
  });

  group('settings CRUD', () {
    test('seeds the four defaults on first run', () async {
      final settings = await db.getAllSettings();
      expect(settings, {
        'latitude': '23.8103',
        'longitude': '90.4125',
        'theme_mode': 'system',
        'notification_enabled': 'true',
      });
    });

    test('reads a single setting and returns null for a missing one', () async {
      expect(await db.getSetting('latitude'), '23.8103');
      expect(await db.getSetting('nope'), isNull);
    });

    test('writes and overwrites a setting', () async {
      await db.setSetting('theme_mode', 'dark');
      expect(await db.getSetting('theme_mode'), 'dark');
      await db.setSetting('theme_mode', 'light');
      expect(await db.getSetting('theme_mode'), 'light');
    });

    test('writes several settings in one transaction', () async {
      await db.setSettings({'latitude': '1.5', 'longitude': '2.5'});
      final settings = await db.getAllSettings();
      expect(settings['latitude'], '1.5');
      expect(settings['longitude'], '2.5');
      // Untouched keys survive.
      expect(settings['theme_mode'], 'system');
    });

    test('deletes one setting and all settings', () async {
      expect(await db.deleteSetting('latitude'), 1);
      expect(await db.getSetting('latitude'), isNull);
      expect(await db.deleteAllSettings(), 3);
      expect(await db.getAllSettings(), isEmpty);
    });
  });

  group('resetAllData', () {
    test('clears every table and re-seeds defaults', () async {
      await db.insertCycle(CycleEntry(startDate: DateTime(2026, 1, 1)));
      await db.setSetting('theme_mode', 'dark');

      await db.resetAllData();

      expect(await db.countCycles(), 0);
      expect(await db.getAllClimateSnapshots(), isEmpty);
      expect(await db.getSetting('theme_mode'), 'system');
      expect(await db.getSetting('latitude'), '23.8103');
    });
  });

  group('migrations', () {
    test('rejects a downgrade instead of corrupting data', () async {
      // Needs a real file: an in-memory database is discarded on close, so
      // there would be no version to find "too new" on reopen.
      final dir = await Directory.systemTemp.createTemp('elara_db_test');
      final filePath = p.join(dir.path, 'elara.db');
      db.overridePath = filePath;
      await db.close();

      final database = await db.database;
      expect(await database.getVersion(), DatabaseHelper.schemaVersion);

      // Simulate a database written by a newer version of the app.
      await database.setVersion(5);
      await db.close();

      await expectLater(db.database, throwsA(isA<StateError>()));
      await dir.delete(recursive: true);
    });

  });

  // One test per table, each walking create -> read -> update -> delete in
  // order. The narrower tests above pin individual queries; these pin the whole
  // round trip, which is what the providers actually do.
  group('CRUD round-trips', () {
    test('cycles round-trips through create, read, update and delete', () async {
      final created = await db.insertCycle(
        CycleEntry(startDate: DateTime(2026, 3, 4), duration: 5),
      );
      expect(created.id, isNotNull);
      final id = created.id!;

      final read = await db.getCycleById(id);
      expect(read, isNotNull);
      expect(dateKey(read!.startDate), '2026-03-04');
      expect(read.duration, 5);

      final updated = await db.updateCycle(read.copyWith(duration: 7));
      expect(updated, 1);

      final reread = await db.getCycleById(id);
      expect(reread!.duration, 7);
      // createdAt survives the update, so ordering by it stays stable.
      expect(reread.createdAt, read.createdAt);

      expect(await db.deleteCycle(id), 1);
      expect(await db.getCycleById(id), isNull);
      expect(await db.countCycles(), 0);
    });

    test('climate_cache round-trips through create, read, update and delete',
        () async {
      ClimateSnapshot snapshot(double temperature) => ClimateSnapshot(
            date: DateTime(2026, 6, 15),
            temperature: temperature,
            humidity: 80,
            heatIndex: temperature + 6,
            sunshineHours: 5.5,
            pm25: 42,
            aqiCategory: 'Moderate',
            fetchedAt: DateTime(2026, 6, 15, 9),
            seasonNote: 'Monsoon',
          );

      final created = await db.upsertClimate(snapshot(30));
      expect(created.id, isNotNull);

      final read = await db.getClimateFor(DateTime(2026, 6, 15));
      expect(read, isNotNull);
      expect(read!.temperature, 30);
      expect(dateKey(read.date), '2026-06-15');
      // isFallback and seasonNote are derived at fetch time and are deliberately
      // not columns: a row in this table is a live reading by definition, since
      // the service never caches an estimate.
      expect(read.isFallback, isFalse);
      expect(read.seasonNote, isNull);

      // The same date is an update, not a second row: the table is keyed by day.
      await db.upsertClimate(snapshot(34));
      final reread = await db.getClimateFor(DateTime(2026, 6, 15));
      expect(reread!.temperature, 34);
      expect(reread.heatIndex, 40);
      expect(await db.getAllClimateSnapshots(), hasLength(1));

      expect(await db.deleteClimateFor(DateTime(2026, 6, 15)), 1);
      expect(await db.getClimateFor(DateTime(2026, 6, 15)), isNull);
    });

    test('settings round-trips through create, read, update and delete',
        () async {
      // A custom key, so the seeded defaults cannot mask a broken write.
      expect(await db.getSetting('round_trip_key'), isNull);

      await db.setSetting('round_trip_key', 'first');
      expect(await db.getSetting('round_trip_key'), 'first');

      await db.setSetting('round_trip_key', 'second');
      expect(await db.getSetting('round_trip_key'), 'second');

      // Overwriting must not duplicate the key.
      final all = await (await db.database).query('settings');
      expect(
        all.where((row) => row['key'] == 'round_trip_key').length,
        1,
      );

      expect(await db.deleteSetting('round_trip_key'), 1);
      expect(await db.getSetting('round_trip_key'), isNull);
      expect(await db.deleteSetting('round_trip_key'), 0);
    });
  });
}
