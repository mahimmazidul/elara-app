import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/models/symptom.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/reminders/reminders_screen.dart';
import 'package:elara_app/screens/symptoms/symptoms_screen.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The two new surfaces: the symptom log and the reminder list.
///
/// What is checked here is mostly what the screens *do not* say: no score, no
/// streak, no diagnosis, no symptom invented from a phase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late SymptomsProvider symptoms;
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
    symptoms = SymptomsProvider(database: db);
    reminders = RemindersProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    await tester.runAsync(() async {
      await symptoms.load();
      await reminders.load();
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
            ChangeNotifierProvider<RemindersProvider>.value(value: reminders),
          ],
          child: MaterialApp(theme: ElaraTheme.light(), home: screen),
        ),
      ),
    );
    await tester.pump();
  }

  group('symptoms', () {
    testWidgets('an empty log is quiet and explainable', (tester) async {
      await pump(tester, const SymptomsScreen());

      expect(tester.takeException(), isNull);
      expect(find.textContaining('optional'), findsWidgets);
      // The log never claims an empty day means a symptom-free day.
      expect(find.textContaining('means a symptom is happening'), findsNothing);
    });

    testWidgets('a logged symptom appears with its own wording',
        (tester) async {
      await tester.runAsync(() => symptoms.log(
            date: today,
            kind: SymptomKind.cramps,
            severity: 2,
          ));
      await pump(tester, const SymptomsScreen());

      expect(find.text('Cramps'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      // No number, no index, no badge.
      expect(find.textContaining('score'), findsNothing);
    });

    testWidgets('tapping a row opens the editor with that entry loaded',
        (tester) async {
      await tester.runAsync(() => symptoms.log(
            date: today,
            kind: SymptomKind.headache,
            severity: 1,
            note: 'behind the eyes',
          ));
      await pump(tester, const SymptomsScreen());

      await tester.tap(find.text('Headache'));
      await tester.pumpAndSettle();

      expect(find.text('Edit this record'), findsOneWidget);
      expect(find.text('behind the eyes'), findsOneWidget);
    });

    testWidgets('the editor saves a new entry and closes', (tester) async {
      await pump(tester, const SymptomsScreen());

      await tester.tap(find.text('Record a symptom').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fatigue'));
      await tester.pump();
      await tester.ensureVisible(find.text('Record'));
      await tester.pumpAndSettle();
      // The save writes to SQLite through an isolate, so the tap has to happen
      // inside runAsync or the future never completes under fake async.
      await tester.runAsync(() async {
        await tester.tap(find.text('Record'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(symptoms.recent.single.kind, SymptomKind.fatigue);
      expect(symptoms.recent.single.date, today);
    });
  });

  group('reminders', () {
    testWidgets('an empty list offers the option to skip', (tester) async {
      await pump(tester, const RemindersScreen());

      expect(find.text('Nothing planned yet.'), findsOneWidget);
      expect(find.textContaining('works the same without it'), findsOneWidget);
    });

    testWidgets('a reminder shows its day and note', (tester) async {
      await tester.runAsync(() => reminders.add(
            date: today,
            title: 'Restock supplies',
            note: 'the shop on the corner',
          ));
      await pump(tester, const RemindersScreen());

      expect(find.text('Restock supplies'), findsOneWidget);
      expect(find.textContaining('the shop on the corner'), findsOneWidget);
      expect(find.textContaining('Today'), findsWidgets);
    });

    testWidgets('the tick marks a reminder done without deleting it',
        (tester) async {
      await tester.runAsync(
        () => reminders.add(date: today, title: 'Buy a hot water bottle'),
      );
      await pump(tester, const RemindersScreen());

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Mark as done'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(reminders.all.single.done, isTrue);
      expect(reminders.all, hasLength(1));
      // The heading is an upper-case overline; the reminder moves under it
      // rather than disappearing.
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('Buy a hot water bottle'), findsOneWidget);
    });

    testWidgets('adding from the list stores it on the chosen day',
        (tester) async {
      await pump(tester, const RemindersScreen());

      await tester.tap(find.text('Plan something'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Bring the heat pack');
      await tester.ensureVisible(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Add'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(reminders.all.single.title, 'Bring the heat pack');
      expect(reminders.all.single.date, today);
    });

    testWidgets('a blank reminder is refused with a plain message',
        (tester) async {
      await pump(tester, const RemindersScreen());

      await tester.tap(find.text('Plan something'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Add'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('Write what you want to remember.'), findsOneWidget);
      expect(reminders.all, isEmpty);
    });
  });

  group('rendered text', () {
    // A doubled backslash in a Dart string literal renders as the literal
    // characters rather than as the separator it was meant to be. The reminder
    // list shipped with exactly that bug, so it is checked rather than trusted.
    Future<void> expectNoLiteralEscapes(WidgetTester tester) async {
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        final data = widget.data;
        if (data == null) continue;
        expect(
          data.contains(r'\u'),
          isFalse,
          reason: 'a Text renders a literal escape sequence: $data',
        );
      }
    }

    testWidgets('the reminder list uses a real separator', (tester) async {
      await tester.runAsync(() => reminders.add(
            date: today,
            title: 'Restock supplies',
            note: 'the shop on the corner',
          ));
      await pump(tester, const RemindersScreen());

      await expectNoLiteralEscapes(tester);
      expect(find.textContaining('·'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final width in <double>[320, 360, 390, 430]) {
      for (final scale in <double>[1.0, 1.5, 2.0]) {
        testWidgets(
          'both screens hold at ${width.toInt()}dp and ${scale}x text',
          (tester) async {
            await tester.runAsync(() async {
              await symptoms.log(
                date: today,
                kind: SymptomKind.breastTenderness,
                severity: 2,
                note: 'both sides, more in the evening',
              );
              await reminders.add(
                date: today,
                title: 'Restock supplies before the weekend',
                note: 'the shop on the corner closes at eight',
              );
              await reminders.add(
                date: today.add(const Duration(days: 2)),
                title: 'Something she would enjoy',
              );
            });

            await pump(
              tester,
              const SymptomsScreen(),
              size: Size(width, 800),
              textScale: scale,
            );
            expect(tester.takeException(), isNull);

            await pump(
              tester,
              const RemindersScreen(),
              size: Size(width, 800),
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
