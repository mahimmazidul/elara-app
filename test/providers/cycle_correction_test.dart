import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Correcting a recorded start, which the app could not do before.
///
/// The guards matter more than the happy path: `start_date` is unique, and a
/// silent collision or a move into the future would corrupt every downstream
/// "days until" figure without ever throwing.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;
  late CycleProvider cycles;

  setUp(() async {
    db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
    await db.close();
    await db.resetAllData();
    cycles = CycleProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  Future<CycleEntry> seed(DateTime start, {int? duration = 5}) async {
    final stored = await db.insertCycle(
      CycleEntry(startDate: start, duration: duration),
    );
    await cycles.load();
    return stored;
  }

  group('moveStartDate', () {
    test('moves a start and persists the new date', () async {
      final entry = await seed(DateTime(2026, 1, 10));
      expect(
        await cycles.moveStartDate(entry.id!, DateTime(2026, 1, 12)),
        isTrue,
      );

      final stored = await db.getCycleById(entry.id!);
      expect(stored!.startDate, DateTime(2026, 1, 12));
      expect(cycles.lastError, isNull);
      // The in-memory list is reloaded, not patched.
      expect(cycles.cycles.single.startDate, DateTime(2026, 1, 12));
    });

    test('bumps the revision so the prediction recomputes', () async {
      final entry = await seed(DateTime(2026, 1, 10));
      final before = cycles.revision;
      await cycles.moveStartDate(entry.id!, DateTime(2026, 1, 12));
      expect(cycles.revision, greaterThan(before));
    });

    test('refuses a move into the future', () async {
      final entry = await seed(DateTime(2026, 1, 10));
      final future = DateTime.now().add(const Duration(days: 5));

      expect(await cycles.moveStartDate(entry.id!, future), isFalse);
      expect(cycles.lastError, contains('future'));
      expect((await db.getCycleById(entry.id!))!.startDate,
          DateTime(2026, 1, 10));
    });

    test('refuses to collide with another recorded start', () async {
      final a = await seed(DateTime(2026, 1, 10));
      await seed(DateTime(2026, 3, 10));

      expect(
        await cycles.moveStartDate(a.id!, DateTime(2026, 3, 10)),
        isFalse,
      );
      expect(cycles.lastError, contains('already a period recorded'));
      // Both rows survive untouched.
      expect(await db.countCycles(), 2);
      expect((await db.getCycleById(a.id!))!.startDate, DateTime(2026, 1, 10));
    });

    test('moving to the same date is a no-op, not an error', () async {
      final entry = await seed(DateTime(2026, 1, 10));
      expect(
        await cycles.moveStartDate(entry.id!, DateTime(2026, 1, 10)),
        isTrue,
      );
      expect(cycles.lastError, isNull);
      expect(await db.countCycles(), 1);
    });

    test('reports a period that has since disappeared', () async {
      final entry = await seed(DateTime(2026, 1, 10));
      await db.deleteCycle(entry.id!);

      expect(
        await cycles.moveStartDate(entry.id!, DateTime(2026, 1, 12)),
        isFalse,
      );
      expect(cycles.lastError, contains('no longer exists'));
    });

    test('keeps the recorded duration', () async {
      final entry = await seed(DateTime(2026, 1, 10), duration: 6);
      await cycles.moveStartDate(entry.id!, DateTime(2026, 1, 14));
      final stored = await db.getCycleById(entry.id!);
      expect(stored!.duration, 6);
    });
  });

  group('entryOn', () {
    test('finds the entry for a day, ignoring the time', () async {
      await seed(DateTime(2026, 1, 10));
      expect(cycles.entryOn(DateTime(2026, 1, 10, 23, 59)), isNotNull);
      expect(cycles.entryOn(DateTime(2026, 1, 11)), isNull);
    });

    test('is empty for a projected day', () async {
      await seed(DateTime(2026, 1, 10));
      expect(cycles.entryOn(DateTime(2026, 1, 20)), isNull);
    });
  });

  group('remove after move', () {
    test('remove works on the corrected date', () async {
      final entry = await seed(DateTime(2026, 1, 10));
      await cycles.moveStartDate(entry.id!, DateTime(2026, 1, 12));

      final corrected = cycles.entryOn(DateTime(2026, 1, 12));
      expect(corrected, isNotNull);
      expect(await cycles.deleteCycle(corrected!.id!), isTrue);
      expect(await db.countCycles(), 0);
    });
  });
}
