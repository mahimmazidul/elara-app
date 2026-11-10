import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/date_keys.dart';
import 'package:elara_app/utils/phase_timeline.dart';
import 'package:elara_app/providers/consent_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/calendar/day_detail_sheet.dart';
import 'package:elara_app/screens/consent/consent_screen.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:elara_core/elara_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The screens that are not in `text_scale_sweep_test.dart`, laid out at the
/// text scales Android offers.
///
/// `text_scale_sweep_test.dart` covers the routes the tabs push. This covers
/// the two screens that are not routes at all:
///
///   * the consent gate, which is the first thing a person sees and the one
///     they see before they have entered anything, so every one of its
///     strings is fixed-length and written by hand - the shape most likely
///     to break a row at 2x text;
///   * the day-detail sheet, which is a modal sheet rather than a page, and
///     so is height-constrained rather than width-constrained. It has its own
///     maximum-height rule, and that rule is exactly what a large text scale
///     would push past.
///
/// It also covers the **tablet** width, which the other sweep does not. The
/// brief asks for compact, standard and large phones *and* tablets, and the
/// navigation rail appears at 720 dp, so the layout path is different there:
/// a centred content column beside a rail, rather than a full-width column.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The scales Android offers in its font-size settings.
  const scales = <double>[1.0, 1.3, 1.5, 2.0];

  /// The widths that actually break Flutter apps, plus the tablet.
  const widths = <double>[320, 390, 1024];

  late DatabaseHelper db;
  late ConsentProvider consent;
  late CycleProvider cycles;
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
    consent = ConsentProvider(database: db);
    cycles = CycleProvider(database: db);
    symptoms = SymptomsProvider(database: db);
    reminders = RemindersProvider(database: db);
    preferences = PreferencesProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  /// Pumps [screen] at [width] with the text at [textScale].
  Future<void> pumpAt(
    WidgetTester tester, {
    required Widget screen,
    required double width,
    required double textScale,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The consent screen reads the recorded decision, so the provider has to
    // be loaded before the screen is built.
    await tester.runAsync(() async {
      await consent.load();
      await cycles.load();
      await symptoms.load();
      await reminders.load();
      await preferences.load();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ConsentProvider>.value(value: consent),
            ChangeNotifierProvider<CycleProvider>.value(value: cycles),
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

  group('consent gate', () {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpAt(
            tester,
            screen: const ConsentScreen(state: ConsentState.unknown),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Consent at ${width.toInt()}dp, ${scale}x',
          );
        });
      }
    }
  });

  group('day detail sheet', () {
    // A day in the middle of the cycle, with something recorded against it,
    // so the sheet shows its longest content rather than an empty day.
    final day = PhaseDay(
      date: dateOnly(DateTime.now().subtract(const Duration(days: 20))),
      phase: core.CyclePhase.lutealEarly,
      cycleDay: 21,
      cycleIndex: 0,
      isRecorded: true,
    );

    // A severity result, so the sheet shows the part of itself that carries
    // the most text: the reasoning and the caveat under the score.
    final severity = core.SeverityResult(
      severityScore: 0.62,
      baseSeverity: 0.5,
      modifier: 1.12,
      hydrationMultiplier: 1.0,
      modifiersApplied: const {'heat': 1.12},
    );

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('lays out at ${width.toInt()}dp and ${scale}x',
            (tester) async {
          await pumpAt(
            tester,
            screen: Scaffold(
              body: DayDetailSheet(day: day, severity: severity),
            ),
            width: width,
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'Day detail at ${width.toInt()}dp, ${scale}x',
          );
        });
      }
    }
  });

  group('a tall phone', () {
    // The brief names large phones as well as large text. A 430 dp wide
    // phone is the widest that still counts as a phone, and it is the one
    // that leaves the most room for a line to run before it has to wrap.
    for (final scale in scales) {
      testWidgets('the consent gate lays out at 430dp and ${scale}x',
          (tester) async {
        await pumpAt(
          tester,
          screen: const ConsentScreen(state: ConsentState.unknown),
          width: 430,
          textScale: scale,
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'Consent at 430dp, ${scale}x',
        );
      });
    }
  });
}
