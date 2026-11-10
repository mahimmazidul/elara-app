import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'date_keys.dart';
import 'models/care_reminder.dart';
import 'models/climate_snapshot.dart';
import 'models/consent_record.dart';
import 'models/cycle_entry.dart';
import 'models/preference.dart';
import 'models/symptom.dart';

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
  static const int schemaVersion = 4;

  static const String databaseFileName = 'elara.db';

  static const String cyclesTable = 'cycles';
  static const String climateCacheTable = 'climate_cache';
  static const String settingsTable = 'settings';
  static const String consentTable = 'consent_records';
  static const String preferencesTable = 'preferences';
  static const String symptomsTable = 'symptoms';
  static const String remindersTable = 'care_reminders';

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
  /// Version 1 is the initial schema. Version 2 adds the consent log.
  ///
  /// The v2 migration deliberately does **not** write a consent row for users
  /// upgrading with existing cycles. Inferring "she must have agreed because
  /// dates were entered" is exactly the assumption this table exists to avoid.
  /// The user is asked on the next launch instead; see [ConsentProvider].
  static const List<Future<void> Function(Database db)?> _migrations = [
    null, // v1: initial schema, created by _onCreate
    _migrateToV2,
    _migrateToV3,
    _migrateToV4,
  ];

  /// Adds the append-only consent log. Safe to run twice: a user who installed
  /// v2 directly never reaches here, because [_onCreate] builds the table.
  static Future<void> _migrateToV2(Database db) async {
    await db.execute(_consentTableStatement);
    await db.execute(
      'CREATE INDEX idx_consent_recorded_at ON $consentTable (recorded_at)',
    );
  }

  /// Adds partner preferences and symptom reports.
  ///
  /// This is a pre-release build with no production installs, so the migration
  /// is written the same way it would be for a version that had them: it adds
  /// tables and touches no existing row. Nothing is inferred into the new
  /// tables, in particular no preference is invented for an existing user.
  static Future<void> _migrateToV3(Database db) async {
    for (final statement in _v3Statements) {
      await db.execute(statement);
    }
  }

  /// Adds date-specific care reminders: the "remember to" list.
  ///
  /// Deliberately not a task manager. A reminder here is one line attached to one
  /// day — bring the hot water bottle, the scan is on Thursday, buy the chocolate
  /// she likes — because the app's job is to help someone remember, not to run
  /// their week.
  static Future<void> _migrateToV4(Database db) async {
    for (final statement in _v4Statements) {
      await db.execute(statement);
    }
    // Early builds of the symptoms table wrote a full ISO-8601 instant into the
    // `date` column, while every query compares against a `yyyy-MM-dd` key, so
    // those rows were invisible to date filters. Rewriting the value keeps the
    // record — no row is dropped — and makes it readable again.
    await db.rawUpdate(
      "UPDATE $symptomsTable SET date = substr(date, 1, 10) "
      "WHERE date LIKE '%T%'",
    );
  }

  static const List<String> _v4Statements = [
    _remindersTableStatement,
    'CREATE INDEX idx_reminders_date ON $remindersTable (date)',
  ];

  static const List<String> _v3Statements = [
    _preferencesTableStatement,
    _symptomsTableStatement,
    'CREATE INDEX idx_preferences_category ON $preferencesTable (category)',
    'CREATE INDEX idx_symptoms_date ON $symptomsTable (date)',
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
    _consentTableStatement,
    _preferencesTableStatement,
    _symptomsTableStatement,
    _remindersTableStatement,
    // Sorted reads of full history are the hot path for prediction.
    'CREATE INDEX idx_cycles_start_date ON $cyclesTable (start_date)',
    'CREATE INDEX idx_climate_date ON $climateCacheTable (date)',
    'CREATE INDEX idx_consent_recorded_at ON $consentTable (recorded_at)',
    'CREATE INDEX idx_preferences_category ON $preferencesTable (category)',
    'CREATE INDEX idx_symptoms_date ON $symptomsTable (date)',
    'CREATE INDEX idx_reminders_date ON $remindersTable (date)',
  ];

  static const String _preferencesTableStatement = '''
    CREATE TABLE $preferencesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      value TEXT NOT NULL,
      source TEXT NOT NULL,
      status TEXT NOT NULL,
      shared INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    )
    ''';

  static const String _symptomsTableStatement = '''
    CREATE TABLE $symptomsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      kind TEXT NOT NULL,
      severity INTEGER NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      UNIQUE (date, kind)
    )
    ''';

  static const String _remindersTableStatement = '''
    CREATE TABLE $remindersTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      title TEXT NOT NULL,
      note TEXT,
      done INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''';

  static const String _consentTableStatement = '''
    CREATE TABLE $consentTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      method TEXT NOT NULL,
      recorded_at TEXT NOT NULL
    )
    ''';

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
      await txn.delete(consentTable);
      await txn.delete(preferencesTable);
      await txn.delete(symptomsTable);
      await txn.delete(remindersTable);
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

  /// Replaces the whole history with [cycles] in a single transaction.
  ///
  /// Used by the restore path. Transactional because a half-applied restore
  /// would leave the prediction reading a history that never existed: either
  /// every row is the backup's or none of it is.
  Future<void> replaceAllCycles(List<CycleEntry> cycles) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(cyclesTable);
      final batch = txn.batch();
      for (final cycle in cycles) {
        batch.insert(
          cyclesTable,
          cycle.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);
    });
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

  // -------------------------------------------------------------- consent --

  /// The full consent log, oldest first. Small by construction: at most a
  /// handful of rows for the life of an install.
  Future<List<ConsentRecord>> getConsentRecords() async {
    final db = await database;
    final rows = await db.query(consentTable, orderBy: 'recorded_at ASC, id ASC');
    return rows.map(ConsentRecord.fromMap).toList();
  }

  /// The most recent consent event, or null when nothing has ever been decided.
  Future<ConsentRecord?> getLatestConsentRecord() async {
    final db = await database;
    final rows = await db.query(
      consentTable,
      orderBy: 'recorded_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ConsentRecord.fromMap(rows.first);
  }

  /// Appends a consent event. The log is append-only, so this never updates or
  /// replaces an earlier row.
  Future<ConsentRecord> addConsentRecord(ConsentRecord record) async {
    final db = await database;
    final id = await db.insert(consentTable, record.toMap());
    return ConsentRecord(
      id: id,
      action: record.action,
      method: record.method,
      recordedAt: record.recordedAt,
    );
  }

  // ---------------------------------------------------------- preferences --

  /// Every stored preference, oldest update last, so a list reads naturally.
  Future<List<Preference>> getAllPreferences() async {
    final db = await database;
    final rows = await db.query(
      preferencesTable,
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows.map(Preference.fromMap).toList();
  }

  Future<List<Preference>> getPreferencesByCategory(
    PreferenceCategory category,
  ) async {
    final db = await database;
    final rows = await db.query(
      preferencesTable,
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows.map(Preference.fromMap).toList();
  }

  Future<Preference?> getPreferenceById(int id) async {
    final db = await database;
    final rows = await db.query(
      preferencesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Preference.fromMap(rows.first);
  }

  Future<Preference> insertPreference(Preference preference) async {
    final db = await database;
    final id = await db.insert(preferencesTable, preference.toMap());
    return preference.copyWith(id: id);
  }

  Future<int> updatePreference(Preference preference) async {
    final id = preference.id;
    if (id == null) {
      throw ArgumentError('Cannot update a preference that has no id.');
    }
    final db = await database;
    return db.update(
      preferencesTable,
      preference.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePreference(int id) async {
    final db = await database;
    return db.delete(preferencesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllPreferences() async {
    final db = await database;
    return db.delete(preferencesTable);
  }

  Future<int> countPreferences() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $preferencesTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ------------------------------------------------------------- symptoms --

  /// Symptoms in a date range, newest day first.
  Future<List<Symptom>> getSymptomsBetween(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      symptomsTable,
      where: 'date >= ? AND date <= ?',
      whereArgs: [dateKey(from), dateKey(to)],
      orderBy: 'date DESC, kind ASC',
    );
    return rows.map(Symptom.fromMap).toList();
  }

  Future<List<Symptom>> getSymptomsOn(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      symptomsTable,
      where: 'date = ?',
      whereArgs: [dateKey(date)],
      orderBy: 'kind ASC',
    );
    return rows.map(Symptom.fromMap).toList();
  }

  /// Symptoms on or after [from], used by the care engine to notice a bad day.
  Future<List<Symptom>> getSymptomsSince(DateTime from) async {
    final db = await database;
    final rows = await db.query(
      symptomsTable,
      where: 'date >= ?',
      whereArgs: [dateKey(from)],
      orderBy: 'date DESC',
    );
    return rows.map(Symptom.fromMap).toList();
  }

  /// Inserts, or replaces the severity and note of an existing day/kind pair.
  ///
  /// Logging the same symptom twice on one day means "it is still there and it
  /// is this bad", not "two headaches", so the unique index makes this idempotent.
  Future<Symptom> upsertSymptom(Symptom symptom) async {
    final db = await database;
    await db.insert(
      symptomsTable,
      symptom.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final rows = await db.query(
      symptomsTable,
      where: 'date = ? AND kind = ?',
      whereArgs: [dateKey(symptom.date), symptom.kind.name],
      limit: 1,
    );
    return rows.isEmpty ? symptom : Symptom.fromMap(rows.first);
  }

  Future<int> deleteSymptom(int id) async {
    final db = await database;
    return db.delete(symptomsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllSymptoms() async {
    final db = await database;
    return db.delete(symptomsTable);
  }

  Future<int> countSymptoms() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $symptomsTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ------------------------------------------------------------ reminders --

  /// Reminders in a date range, earliest day first, undated-of-day last.
  Future<List<CareReminder>> getRemindersBetween(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    final rows = await db.query(
      remindersTable,
      where: 'date >= ? AND date <= ?',
      whereArgs: [dateKey(from), dateKey(to)],
      orderBy: 'date ASC, done ASC, id ASC',
    );
    return rows.map(CareReminder.fromMap).toList();
  }

  Future<List<CareReminder>> getRemindersOn(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      remindersTable,
      where: 'date = ?',
      whereArgs: [dateKey(date)],
      orderBy: 'done ASC, id ASC',
    );
    return rows.map(CareReminder.fromMap).toList();
  }

  Future<CareReminder> insertReminder(CareReminder reminder) async {
    final db = await database;
    final id = await db.insert(remindersTable, reminder.toMap());
    return reminder.copyWith(id: id);
  }

  Future<int> updateReminder(CareReminder reminder) async {
    final db = await database;
    return db.update(
      remindersTable,
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return db.delete(remindersTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllReminders() async {
    final db = await database;
    return db.delete(remindersTable);
  }

  Future<int> countReminders() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $remindersTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
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
