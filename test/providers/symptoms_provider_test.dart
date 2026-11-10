import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/models/symptom.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Symptom logging: dates, persistence, correction, deletion, expiry.
///
/// Every assertion here is about a record the user made. Nothing in this file
/// checks a symptom being derived from a phase, because Elara does not do that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late SymptomsProvider symptoms;
  final today = dateOnly(DateTime.now());

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance;
    db.overridePath = inMemoryDatabasePath;
    await db.close();
    // A bare DateOnly local midnight, to prove the provider does not force a
    // time-of-day convention on what it is given.
    symptoms = SymptomsProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  test('a symptom is stored against the day it was given', () async {
    await symptoms.log(
      date: today,
      kind: SymptomKind.cramps,
      severity: 2,
      note: 'lower back too',
    );

    final stored = symptoms.recent.single;
    expect(stored.kind, SymptomKind.cramps);
    expect(stored.severity, 2);
    expect(stored.note, 'lower back too');
    expect(dateOnly(stored.date), today);
    expect(symptoms.on(today), hasLength(1));
  });

  test('a time of day inside the date is dropped, not stored', () async {
    // 23:40 on the chosen day is still that day.
    await symptoms.log(
      date: DateTime(today.year, today.month, today.day, 23, 40),
      kind: SymptomKind.headache,
      severity: 1,
    );

    expect(symptoms.recent.single.date, today);
    expect(symptoms.markerDays(), {today});
  });

  test('a future date is refused', () async {
    final ok = await symptoms.log(
      date: today.add(const Duration(days: 3)),
      kind: SymptomKind.fatigue,
      severity: 2,
    );

    expect(ok, isFalse);
    expect(symptoms.recent, isEmpty);
    expect(await db.countSymptoms(), 0);
  });

  test('several symptoms on one day all survive', () async {
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 2);
    await symptoms.log(date: today, kind: SymptomKind.bloating, severity: 1);
    await symptoms.log(date: today, kind: SymptomKind.nausea, severity: 1);

    expect(symptoms.on(today), hasLength(3));
    expect(symptoms.markerDays().length, 1);
  });

  test('correcting severity and note updates in place', () async {
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 1);
    final original = symptoms.recent.single;

    final ok = await symptoms.log(
      date: today,
      kind: SymptomKind.cramps,
      severity: 3,
      note: 'needed a heat pack',
      replacing: original,
    );

    expect(ok, isTrue);
    expect(symptoms.recent, hasLength(1));
    expect(symptoms.recent.single.severity, 3);
    expect(symptoms.recent.single.note, 'needed a heat pack');
    // The corrected entry is the only one left for that day and kind.
    expect(await db.countSymptoms(), 1);
    expect(symptoms.recent.single.id, isNotNull);
  });

  test('correcting the kind or the day leaves no duplicate behind', () async {
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 2);
    final original = symptoms.recent.single;

    // The wrong kind was picked, and the day was wrong too.
    final yesterday = today.subtract(const Duration(days: 1));
    final ok = await symptoms.log(
      date: yesterday,
      kind: SymptomKind.headache,
      severity: 2,
      replacing: original,
    );

    expect(ok, isTrue);
    expect(symptoms.recent, hasLength(1));
    expect(symptoms.recent.single.kind, SymptomKind.headache);
    expect(symptoms.recent.single.date, yesterday);
    expect(await db.countSymptoms(), 1);
  });

  test('an out-of-range severity is refused', () async {
    final ok = await symptoms.log(
      date: today,
      kind: SymptomKind.cramps,
      severity: 7,
    );

    expect(ok, isFalse);
    expect(symptoms.recent, isEmpty);
  });

  test('deleting removes just that entry', () async {
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 2);
    await symptoms.log(date: today, kind: SymptomKind.headache, severity: 1);

    await symptoms.delete(symptoms.recent.first.id!);

    expect(symptoms.recent, hasLength(1));
    expect(symptoms.recent.single.kind, SymptomKind.headache);
  });

  test('entries older than the window are not shown or marked', () async {
    final longAgo = today.subtract(const Duration(days: 200));
    // Written straight to the database, so this really is an old row rather
    // than something the provider's 60-day window would have produced.
    await db.upsertSymptom(
      Symptom(
        date: longAgo,
        kind: SymptomKind.fatigue,
        severity: 2,
        createdAt: longAgo,
      ),
    );
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 2);

    expect(symptoms.on(longAgo), isEmpty);
    expect(symptoms.markerDays().contains(longAgo), isFalse);
    expect(
      symptoms.markerDays().contains(
        today.subtract(const Duration(days: SymptomsProvider.windowDays + 1)),
      ),
      isFalse,
    );
    // The old row is not deleted: the window limits what is shown, not what is
    // kept.
    expect(await db.countSymptoms(), 2);
  });

  test('symptoms do not imply a cycle record', () async {
    await symptoms.log(date: today, kind: SymptomKind.bleeding, severity: 2);

    // Logging bleeding is not the same as recording a period start, and the
    // provider must not write one.
    expect(await db.countCycles(), 0);
  });

  test('the summary speaks in days, not scores', () async {
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 2);
    await symptoms.log(
      date: today.subtract(const Duration(days: 2)),
      kind: SymptomKind.headache,
      severity: 1,
    );

    expect(symptoms.summary, 'Recorded on 2 days');
    expect(symptoms.summary, isNot(contains('%')));
  });

  test('a logged symptom is offered to the care engine as reported evidence',
      () async {
    await symptoms.log(date: today, kind: SymptomKind.cramps, severity: 2);

    // recent is what CareRecommender reads. It carries the kind, so care can say
    // "you mentioned cramps" rather than guessing.
    expect(symptoms.recent.single.kind, SymptomKind.cramps);
    expect(symptoms.recent.single.kind.label, isNotEmpty);
    expect(symptoms.recent.single.severityLabel, isNotEmpty);
  });

  test('each kind has a label and a scale of its own', () {
    for (final kind in SymptomKind.values) {
      expect(kind.label, isNotEmpty);
      expect(kind.scaleLow, isNotEmpty);
      expect(kind.scaleHigh, isNotEmpty);
    }
  });
}
