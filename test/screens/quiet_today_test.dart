import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_mode.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/today/quiet_today.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// What the Today screen says when Elara has been told not to predict.
///
/// The assertions that matter are the negative ones. A paused app that still
/// renders "Next period in 4 days" has not paused anything; it has only
/// reworded the same claim, and for someone after a miscarriage that sentence
/// is the whole product.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late SettingsProvider settings;
  late PreferencesProvider preferences;
  late SymptomsProvider symptoms;
  late RemindersProvider reminders;
  late ClimateProvider climate;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
    await db.close();
    await db.resetAllData();
    settings = SettingsProvider(database: db);
    preferences = PreferencesProvider(database: db);
    symptoms = SymptomsProvider(database: db);
    reminders = RemindersProvider(database: db);
    climate = ClimateProvider(
      climateService: ClimateService(
        database: db,
        httpClient: MockClient((_) async => http.Response('', 503)),
        timeout: const Duration(seconds: 1),
      ),
    );
    await settings.load();
    await preferences.load();
    await symptoms.load();
    await reminders.load();
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  /// sqflite talks to real I/O, which the fake async zone inside a widget test
  /// never completes, so every database write has to run outside it.
  Future<void> setMode(
    WidgetTester tester,
    CycleMode mode, {
    PauseReason? reason,
  }) async {
    await tester.runAsync(() => settings.setCycleMode(mode, reason: reason));
    expect(settings.cycleMode, mode);
  }

  Future<void> pumpQuiet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 1600)),
        child: MultiProvider(
          providers: [
            Provider<DatabaseHelper>.value(value: db),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<PreferencesProvider>.value(value: preferences),
            ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
            ChangeNotifierProvider<RemindersProvider>.value(value: reminders),
            ChangeNotifierProvider<ClimateProvider>.value(value: climate),
          ],
          child: MaterialApp(
            theme: ElaraTheme.light(),
            home: const Scaffold(body: QuietToday()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hormonal contraception explains itself and claims no date',
      (tester) async {
    await setMode(tester, CycleMode.hormonalContraception);
    await pumpQuiet(tester);

    expect(
      find.text(
        'The forecast is paused while she is on hormonal contraception',
      ),
      findsOneWidget,
    );
    // No cycle claim of any kind survives on the screen.
    expect(find.textContaining('Next period'), findsNothing);
    expect(find.textContaining('days late'), findsNothing);
    expect(find.textContaining('Estimated'), findsNothing);
    expect(find.textContaining('fertile'), findsNothing);
    // And it says the thing people actually want to know. The generic guide
    // stays reachable from Today, even without a phase forecast.
    expect(find.textContaining('Everything else still works'), findsOneWidget);
    expect(find.text('Read the phase guide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loss is described without a single day count', (tester) async {
    await setMode(tester, CycleMode.paused, reason: PauseReason.loss);
    await pumpQuiet(tester);

    expect(find.text('Prediction paused'), findsOneWidget);
    expect(find.textContaining('days late'), findsNothing);
    // The sentence that stops a late period being called a late period.
    expect(find.textContaining('will not call it one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausing without a stated reason still says what is happening',
      (tester) async {
    await setMode(tester, CycleMode.paused);
    await pumpQuiet(tester);

    expect(find.text('Prediction paused'), findsOneWidget);
    expect(find.textContaining('You chose this'), findsOneWidget);
    expect(find.textContaining('logging still works'), findsOneWidget);
    // No reason is demanded and none is invented.
    expect(find.textContaining('pregnan'), findsNothing);
  });

  testWidgets('the quiet screen offers the way back, and it works',
      (tester) async {
    await setMode(tester, CycleMode.paused, reason: PauseReason.pregnancy);
    await pumpQuiet(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Start predicting again'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump();

    expect(settings.cycleMode, CycleMode.predicting);
    expect(settings.pauseReason, isNull);
  });

  testWidgets('care suggestions keep working while prediction is off',
      (tester) async {
    await setMode(tester, CycleMode.hormonalContraception);
    await pumpQuiet(tester);

    // The section survives; it is the *claims* that are gone, not the help.
    expect(find.text('Ways to help today'), findsOneWidget);
    // And it is explicit that the guidance is not phase-derived.
    expect(find.textContaining('Where a phase would normally decide'), findsOneWidget);
  });

  testWidgets('lays out at 320dp and 2.0x text scale', (tester) async {
    await setMode(tester, CycleMode.paused, reason: PauseReason.loss);

    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 1800),
          textScaler: TextScaler.linear(2),
        ),
        child: MultiProvider(
          providers: [
            Provider<DatabaseHelper>.value(value: db),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<PreferencesProvider>.value(value: preferences),
            ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
            ChangeNotifierProvider<RemindersProvider>.value(value: reminders),
            ChangeNotifierProvider<ClimateProvider>.value(value: climate),
          ],
          child: MaterialApp(
            theme: ElaraTheme.light(),
            home: const Scaffold(body: QuietToday()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
