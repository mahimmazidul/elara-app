import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'date_keys.dart';
import 'models/climate_snapshot.dart';
import 'models/cycle_entry.dart';

/// Single owner of the sqflite connection and of all SQL in the app.
///
/// Nothing else in the app should import `package:sqflite` for data access;
/// keeping the schema, the migrations and the queries together is what makes
/// the storage layer auditable. Access with [DatabaseHelper.instance].
///
/// Opening is lazy and shared: concurrent callers await one open rather than
/// racing to create two connections. [_openFuture] is cleared on failure so a
/// transient error does not poison the helper for the rest of the process.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  /// Current schema version. Bump this and add an `if (oldVersion < n)` branch
  /// in [_onUpgrade] whenever the schema changes.
  static const int schemaVersion = 1;

  static const String databaseFileName = 'elara.db';

  static const String cyclesTable = 'cycles';
  static const String climateCacheTable = 'climate_cache';
  static const String settingsTable = 'settings';

  /// Settings written once, on first create.
  static const Map<String, String> defaultSettings = {
    'latitude': '23.8103',
    'longitude': '90.4125',
    'theme_mode': 'system',
    'notification_enabled': 'true',
  };

  Database? _db;
  Future<Database>? _openFuture;

  /// Test seam: overrides the on-disk path, e.g. `inMemoryDatabasePath`.
  String? overridePath;

  /// The open database, opening it on first use.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final pending = _openFuture;
    if (pending != null) return pending;

    final future = _open();
    _openFuture = future;
    try {
      final db = await future;
      _db = db;
      return db;
    } catch (_) {
      _openFuture = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path = overridePath ??
        p.join(await getDatabasesPath(), databaseFileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // sqflite does not call onUpgrade for a downgrade, and its default is to
      // open the file anyway. That would let an older build read rows written
      // under a newer schema, so refuse explicitly instead.
      onDowngrade: _onDowngrade,
    );
  }

  /// Foreign keys are off by default in SQLite and must be enabled per
  /// connection, before any transaction runs.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in _schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);

    // Seed defaults only if absent, so an interrupted create cannot clobber
    // a value the user has already set.
    final batch2 = db.batch();
    for (final entry in defaultSettings.entries) {
      batch2.insert(
        settingsTable,
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    batch2.commit(noResult: true);
  }

  /// Ordered migrations. Each step upgrades exactly one version, so a user
  /// several versions behind replays them in sequence and a fresh install
  /// (which runs [_onCreate] instead) never touches this code.
  ///
  /// Version 1 is the initial schema, so there is nothing to migrate yet. The
  /// empty list is deliberate: the dispatch below is proven to work the moment
  /// version 2 adds its first entry.
  static const List<Future<void> Function(Database db)?> _migrations = [
    null, // v1: initial schema, created by _onCreate
  ];

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    throw StateError(
      'Cannot downgrade the Elara database from v$oldVersion to v$newVersion.',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      final migration = version <= _migrations.length
          ? _migrations[version - 1]
          : null;
      if (migration == null) {
        throw StateError(
          'Missing migration for Elara database v$version '
          '(upgrading $oldVersion -> $newVersion).',
        );
      }
      await migration(db);
    }
  }

  static const List<String> _schemaStatements = [
    '''
    CREATE TABLE $cyclesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      start_date TEXT UNIQUE NOT NULL,
      duration INTEGER,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $climateCacheTable (
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
    CREATE TABLE $settingsTable (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    // Sorted reads of full history are the hot path for prediction.
    'CREATE INDEX idx_cycles_start_date ON $cyclesTable (start_date)',
    'CREATE INDEX idx_climate_date ON $climateCacheTable (date)',
  ];

  /// Closes the connection. Mostly for tests and for the app's teardown path.
  Future<void> close() async {
    final db = _db;
    _db = null;
    _openFuture = null;
    if (db != null && db.isOpen) await db.close();
  }

  /// Drops every row and re-seeds defaults. Intended for the app's "delete all
  /// data" path and for tests; never called during normal use.
  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(cyclesTable);
      await txn.delete(climateCacheTable);
      await txn.delete(settingsTable);
      for (final entry in defaultSettings.entries) {
        await txn.insert(settingsTable, {
          'key': entry.key,
          'value': entry.value,
        });
      }
    });
  }

  // ---------------------------------------------------------------- cycles --

  /// All recorded periods, oldest first, which is the order the prediction
  /// engine requires.
  Future<List<CycleEntry>> getAllCycles() async {
    final db = await database;
    final rows = await db.query(cyclesTable, orderBy: 'start_date ASC, id ASC');
    return rows.map(CycleEntry.fromMap).toList();
  }

  Future<CycleEntry?> getCycleById(int id) async {
    final db = await database;
    final rows = await db.query(
      cyclesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CycleEntry.fromMap(rows.first);
  }

  Future<CycleEntry?> getCycleByStartDate(DateTime startDate) async {
    final db = await database;
    final rows = await db.query(
      cyclesTable,
      where: 'start_date = ?',
      whereArgs: [dateKey(startDate)],
      limit: 1,
    );
    return rows.isEmpty ? null : CycleEntry.fromMap(rows.first);
  }

  /// Most recent period, or null when history is empty.
  Future<CycleEntry?> getLatestCycle() async {
    final db = await database;
    final rows = await db.query(
      cyclesTable,
      orderBy: 'start_date DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : CycleEntry.fromMap(rows.first);
  }

  /// Inserts a period and returns the row with its assigned id.
  ///
  /// Throws [DatabaseException] if the start date already exists; use
  /// [upsertCycle] when "log the same day twice" should be idempotent.
  Future<CycleEntry> insertCycle(CycleEntry cycle) async {
    final db = await database;
    final id = await db.insert(
      cyclesTable,
      cycle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return cycle.copyWith(id: id);
  }

  /// Inserts, or replaces the duration of an existing start date.
  Future<CycleEntry> upsertCycle(CycleEntry cycle) async {
    final db = await database;
    await db.insert(
      cyclesTable,
      cycle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final stored = await getCycleByStartDate(cycle.startDate);
    // `replace` deletes and reinserts, so the id may not be the one passed in.
    return stored ?? cycle;
  }

  Future<int> updateCycle(CycleEntry cycle) async {
    final id = cycle.id;
    if (id == null) {
      throw ArgumentError('Cannot update a cycle that has no id.');
    }
    final db = await database;
    return db.update(
      cyclesTable,
      cycle.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCycle(int id) async {
    final db = await database;
    return db.delete(cyclesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCycleByStartDate(DateTime startDate) async {
    final db = await database;
    return db.delete(
      cyclesTable,
      where: 'start_date = ?',
      whereArgs: [dateKey(startDate)],
    );
  }

  Future<int> deleteAllCycles() async {
    final db = await database;
    return db.delete(cyclesTable);
  }

  Future<int> countCycles() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $cyclesTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Completed cycle lengths in days, oldest first. A single recorded period
  /// yields an empty list because no length can be derived from it.
  Future<List<int>> getCompletedCycleLengths() async {
    final cycles = await getAllCycles();
    final lengths = <int>[];
    for (var i = 1; i < cycles.length; i++) {
      final length = daysBetween(cycles[i - 1].startDate, cycles[i].startDate);
      if (length > 0) lengths.add(length);
    }
    return lengths;
  }

  // ------------------------------------------------------- climate_cache --

  Future<ClimateSnapshot?> getClimateFor(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      climateCacheTable,
      where: 'date = ?',
      whereArgs: [dateKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : ClimateSnapshot.fromMap(rows.first);
  }

  /// Cached climate for [date] if it is still inside the freshness window.
  Future<ClimateSnapshot?> getFreshClimateFor(
    DateTime date, {
    DateTime? now,
  }) async {
    final cached = await getClimateFor(date);
    if (cached == null) return null;
    return cached.isFreshAt(now ?? DateTime.now()) ? cached : null;
  }

  Future<List<ClimateSnapshot>> getAllClimateSnapshots() async {
    final db = await database;
    final rows = await db.query(climateCacheTable, orderBy: 'date ASC');
    return rows.map(ClimateSnapshot.fromMap).toList();
  }

  /// Writes a snapshot, replacing any existing row for the same date, and
  /// returns the stored copy.
  Future<ClimateSnapshot> upsertClimate(ClimateSnapshot snapshot) async {
    final db = await database;
    await db.insert(
      climateCacheTable,
      snapshot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final stored = await getClimateFor(snapshot.date);
    return stored ?? snapshot;
  }

  Future<int> deleteClimateFor(DateTime date) async {
    final db = await database;
    return db.delete(
      climateCacheTable,
      where: 'date = ?',
      whereArgs: [dateKey(date)],
    );
  }

  /// Removes rows older than [keepDays], bounding the table's growth.
  Future<int> pruneClimateBefore(DateTime cutoff) async {
    final db = await database;
    return db.delete(
      climateCacheTable,
      where: 'date < ?',
      whereArgs: [dateKey(cutoff)],
    );
  }

  Future<int> deleteAllClimate() async {
    final db = await database;
    return db.delete(climateCacheTable);
  }

  // ------------------------------------------------------------- settings --

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query(settingsTable, orderBy: 'key ASC');
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Inserts or overwrites one setting. Returns the number of affected rows.
  Future<int> setSetting(String key, String value) async {
    final db = await database;
    return db.insert(
      settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSettings(Map<String, String> values) async {
    if (values.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in values.entries) {
        batch.insert(
          settingsTable,
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> deleteSetting(String key) async {
    final db = await database;
    return db.delete(settingsTable, where: 'key = ?', whereArgs: [key]);
  }

  Future<int> deleteAllSettings() async {
    final db = await database;
    return db.delete(settingsTable);
  }
}
