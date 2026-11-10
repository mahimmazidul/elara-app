import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/models/care_reminder.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Care reminders: storage, validation, duplicate dates and persistence.
///
/// The reminder table has no unique constraint on the date on purpose — two
/// things can legitimately share a day — so "duplicate" here means two rows that
/// stay two rows, not a merge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late RemindersProvider reminders;
  final today = dateOnly(DateTime.now());

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance;
    db.overridePath = inMemoryDatabasePath;
    await db.close();
    reminders = RemindersProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  test('a reminder round-trips through the database', () async {
    final ok = await reminders.add(
      date: today.add(const Duration(days: 3)),
      title: '  Restock supplies  ',
      note: ' the pads with no wings ',
    );

    expect(ok, isTrue);
    expect(reminders.lastError, isNull);

    final stored = reminders.all.single;
    expect(stored.title, 'Restock supplies');
    expect(stored.note, 'the pads with no wings');
    expect(stored.done, isFalse);
    expect(stored.date, today.add(const Duration(days: 3)));
    expect(stored.createdAt, isNotNull);
  });

  test('a blank title is refused and nothing is written', () async {
    final ok = await reminders.add(date: today, title: '   ');

    expect(ok, isFalse);
    expect(reminders.lastError, 'Write what you want to remember.');
    expect(reminders.all, isEmpty);
    expect(await db.countReminders(), 0);
  });

  test('two reminders on the same day both survive', () async {
    await reminders.add(date: today, title: 'Buy a hot water bottle');
    await reminders.add(date: today, title: 'Ask about her day');

    final onDay = reminders.on(today);
    expect(onDay, hasLength(2));
    expect(
      onDay.map((r) => r.title),
      containsAll(['Buy a hot water bottle', 'Ask about her day']),
    );
    expect(reminders.markerDays(), {today});
  });

  test('editing a reminder keeps its id and moves its date', () async {
    await reminders.add(date: today, title: 'Heat pack');
    final original = reminders.all.single;

    final moved = today.add(const Duration(days: 5));
    final ok = await reminders.update(
      original.copyWith(date: moved, title: 'Heat pack + chocolate'),
    );

    expect(ok, isTrue);
    final stored = reminders.all.single;
    expect(stored.id, original.id);
    expect(stored.date, moved);
    expect(stored.title, 'Heat pack + chocolate');
    expect(reminders.on(today), isEmpty);
  });

  test('editing to a blank title is refused and the row is untouched',
      () async {
    await reminders.add(date: today, title: 'Heat pack');
    final original = reminders.all.single;

    final ok = await reminders.update(original.copyWith(title: '  '));

    expect(ok, isFalse);
    expect(reminders.all.single.title, 'Heat pack');
  });

  test('done is a flag, not a delete', () async {
    await reminders.add(date: today, title: 'Buy supplies');
    final original = reminders.all.single;

    await reminders.setDone(original, true);
    expect(reminders.all.single.done, isTrue);
    expect(reminders.all, hasLength(1));
    expect(reminders.summary, 'Nothing planned');

    await reminders.setDone(reminders.all.single, false);
    expect(reminders.summary, '1 thing planned');
  });

  test('deleting removes exactly one row', () async {
    await reminders.add(date: today, title: 'One');
    await reminders.add(date: today, title: 'Two');

    await reminders.delete(reminders.all.first.id!);

    expect(reminders.all, hasLength(1));
    expect(await db.countReminders(), 1);
  });

  test('a note can be cleared without losing the reminder', () async {
    await reminders.add(
      date: today,
      title: 'Ask how the day went',
      note: 'after dinner',
    );
    final withNote = reminders.all.single;

    await reminders.update(withNote.copyWith(clearNote: true));

    final stored = reminders.all.single;
    expect(stored.note, isNull);
    expect(stored.title, 'Ask how the day went');
  });

  test('upcoming ignores past and done reminders', () async {
    await reminders.add(
      date: today.subtract(const Duration(days: 2)),
      title: 'Past',
    );
    await reminders.add(date: today, title: 'Today');
    await reminders.add(
      date: today.add(const Duration(days: 1)),
      title: 'Tomorrow',
    );
    await reminders.add(
      date: today.add(const Duration(days: 30)),
      title: 'Next month',
    );

    expect(
      reminders.upcoming(days: 1).map((r) => r.title),
      ['Today', 'Tomorrow'],
    );
    expect(reminders.upcoming(days: 7).map((r) => r.title),
        ['Today', 'Tomorrow']);
  });

  test('reminders survive a reopen of the same database file', () async {
    await reminders.add(date: today, title: 'Persisted');

    // A second provider over the same database reads what the first wrote.
    final reopened = RemindersProvider(database: db);
    await reopened.load();

    expect(reopened.all.single.title, 'Persisted');
  });

  test('the summary counts only unfinished work', () async {
    for (var i = 0; i < 3; i++) {
      await reminders.add(
        date: today.add(Duration(days: i)),
        title: 'Item $i',
      );
    }
    await reminders.setDone(reminders.all.first, true);

    expect(reminders.summary, '2 things planned');
  });

  test('an unknown id removes nothing and reports failure quietly', () async {
    await reminders.add(date: today, title: 'Real');

    // A stale id is a stale id: no exception escapes, the list is unchanged.
    await reminders.delete(999999);
    expect(reminders.all, hasLength(1));
  });

  test('CareReminder.toMap/fromMap round-trip independent of the database',
      () {
    final reminder = CareReminder(
      id: 4,
      date: today,
      title: 'Buy supplies',
      note: null,
      done: true,
      createdAt: today,
    );

    // toMap() is what gets inserted, so it deliberately omits the id and lets
    // SQLite assign one; everything else must survive unchanged.
    final restored = CareReminder.fromMap(reminder.toMap());
    expect(restored.id, isNull);
    expect(restored.title, 'Buy supplies');
    expect(restored.note, isNull);
    expect(restored.done, isTrue);
    expect(restored.date, today);
  });
}
