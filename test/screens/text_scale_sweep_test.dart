import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/data/medical_content.dart';
import 'package:elara_app/data/models/care_reminder.dart';
import 'package:elara_app/data/models/symptom.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/medical/medical_screen.dart';
import 'package:elara_app/screens/medical/medical_topic_screen.dart';
import 'package:elara_app/screens/preferences/preferences_screen.dart';
import 'package:elara_app/screens/reminders/reminders_screen.dart';
import 'package:elara_app/screens/symptoms/symptoms_screen.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every screen the app can push, laid out at the text scales Android offers.
///
/// `test/widgets/responsive_test.dart` covers the four tabs. This covers the
/// routes they push, which is where the long strings live: a symptom name, a
/// reminder someone wrote, a paragraph of health information, a preference
/// answer. Those are the strings that break a row at 2x text.
///
/// A render overflow is not a cosmetic problem. It paints a yellow-and-black
/// striped banner over the content, and on Android it is what a person sees
/// when they have turned their font size up - which is exactly the person the
/// app should be working hardest for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The scales Android offers in its font-size settings.
  const scales = <double>[1.0, 1.3, 1.5, 2.0];

  /// The widths that actually break Flutter apps.
  const widths = <double>[320, 390];

  late DatabaseHelper db;
  late SymptomsProvider symptoms;
  late RemindersProvider reminders;
  late PreferencesProvider preferences;

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
    preferences = PreferencesProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  Future<void> pumpRoute(
    WidgetTester tester, {
    required Widget screen,
    required double width,
    required double textScale,
  }) async {
    await tester.runAsync(() async {
      // Seed the longest strings the app will ever hold, because an empty
      // screen cannot overflow. These are the shapes that actually break: a
      // symptom with a full-length name and a note somebody actually wrote,
      // and a reminder with a long line and a long detail.
      await db.upsertSymptom(
        Symptom(
          date: dateOnly(DateTime.now()),
          kind: SymptomKind.breastTenderness,
          severity: 3,
          note: 'Worse in the evening, and the ibuprofen helped a little '
              'but not much.',
          createdAt: DateTime.now(),
        ),
      );
      await db.upsertSymptom(
        Symptom(
          date: dateOnly(DateTime.now()),
          kind: SymptomKind.moodChange,
          severity: 2,
          note: 'Snapped at me about something small and then apologised.',
          createdAt: DateTime.now(),
        ),
      );
      await db.insertReminder(
        CareReminder(
          date: dateOnly(DateTime.now()),
          title: 'Pick up the prescription from the pharmacy on the corner',
          note: 'It closes at seven, so go after work if you can.',
          createdAt: DateTime.now(),
        ),
      );
      await db.insertReminder(
        CareReminder(
          date: dateOnly(DateTime.now().add(const Duration(days: 2))),
          title: 'Book the car service',
          note: 'Ask about the tyre pressure as well.',
          done: true,
          createdAt: DateTime.now(),
        ),
      );

      await symptoms.load();
      await reminders.load();
      await preferences.load();
    });

    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
            ChangeNotifierProvider<RemindersProvider>.value(value: reminders),
            ChangeNotifierProvider<PreferencesProvider>.value(value: preferences),
          ],
          child: MaterialApp(
            theme: ElaraTheme.light(phaseKey: 'luteal'),
            home: screen,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('symptoms', () {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpRoute(
            tester,
            screen: const SymptomsScreen(),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Symptoms at ${width.toInt()}dp, ${scale}x',
          );
        });
      }
    }
  });

  group('reminders', () {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpRoute(
            tester,
            screen: const RemindersScreen(),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Reminders at ${width.toInt()}dp, ${scale}x',
          );
        });
      }
    }
  });

  group('preferences', () {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpRoute(
            tester,
            screen: const PreferencesScreen(),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Preferences at ${width.toInt()}dp, ${scale}x',
          );
        });
      }
    }
  });

  group('health information', () {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('the topic list lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpRoute(
            tester,
            screen: const MedicalScreen(),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Medical list at ${width.toInt()}dp, ${scale}x',
          );
        });

        testWidgets('a topic lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpRoute(
            tester,
            screen: MedicalTopicScreen(topic: medicalTopics.first),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'A topic at ${width.toInt()}dp, ${scale}x',
          );
        });
      }
    }
  });
}
