import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/consent_record.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/consent_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/screens/consent/consent_gate.dart';
import 'package:elara_app/screens/root_scaffold.dart';
import 'package:elara_app/screens/settings/settings_screen.dart';
import 'package:elara_app/services/backup_service.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/notification_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Drives the consent gate as a user would, against the real database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance..overridePath = inMemoryDatabasePath;
    await db.close();
    await db.resetAllData();
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  http.Client offline() => MockClient((_) async => http.Response('offline', 503));

  /// Pumps real time until [done] holds, up to a few seconds.
  ///
  /// Database work runs on a background isolate, so a fixed delay is a guess:
  /// generous enough on a fast machine hides a race, and tight enough to be
  /// quick fails intermittently. Waiting on the condition removes the guess.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    String? reason,
  }) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      if (done()) {
        await tester.pump();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    fail('timed out waiting${reason == null ? '' : ' for $reason'}');
  }

  Future<void> pumpGate(WidgetTester tester) async {
    // The consent card is a scroll view; at the default 800x600 test surface
    // its lower buttons fall outside the viewport and taps land on nothing.
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ConsentProvider consent;
    late SettingsProvider settings;
    late CycleProvider cycles;
    late ClimateProvider climate;
    late PredictionProvider prediction;
    late PreferencesProvider preferences;
    late SymptomsProvider symptoms;

    await tester.runAsync(() async {
      final climateService = ClimateService(
        database: db,
        httpClient: offline(),
        timeout: const Duration(seconds: 1),
      );
      consent = ConsentProvider(database: db);
      settings = SettingsProvider(database: db);
      cycles = CycleProvider(database: db);
      climate = ClimateProvider(climateService: climateService);
      prediction = PredictionProvider(
        predictionService: PredictionService(
          database: db,
          climateService: climateService,
        ),
      );
      await consent.load();
      await settings.load();
      await cycles.load();
      await prediction.refresh();
      preferences = PreferencesProvider(database: db);
      symptoms = SymptomsProvider(database: db);
      await preferences.load();
      await symptoms.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          ChangeNotifierProvider<ConsentProvider>.value(value: consent),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CycleProvider>.value(value: cycles),
          ChangeNotifierProvider<ClimateProvider>.value(value: climate),
          ChangeNotifierProvider<PredictionProvider>.value(value: prediction),
          ChangeNotifierProvider<PreferencesProvider>.value(
              value: preferences),
          ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
          ChangeNotifierProvider<RemindersProvider>(create: (_) => RemindersProvider(database: db)..load()),
          Provider<BackupService>(create: (_) => BackupService(database: db)),
          Provider<NotificationRescheduler>(create: (_) => _NoopRescheduler()),
        ],
        child: MaterialApp(
          theme: ElaraTheme.light(),
          home: const ConsentGate(),
        ),
      ),
    );

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }

  group('first run', () {
    testWidgets('the app is not reachable before consent', (tester) async {
      await pumpGate(tester);

      expect(find.text('Before you start'), findsOneWidget);
      expect(find.byType(RootScaffold), findsNothing);
      expect(
        find.text('She knows, and this is fine'),
        findsOneWidget,
      );
    });

    testWidgets('agreeing opens the app', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('She knows, and this is fine'));
      await pumpUntil(tester, () => find.byType(RootScaffold).evaluate().isNotEmpty,
          reason: 'the app to open');

      expect(find.byType(RootScaffold), findsOneWidget);
      expect(find.text('Before you start'), findsNothing);

      // And the decision is on disk.
      final records = await tester.runAsync(db.getConsentRecords);
      expect(records!.single.action.name, 'granted');
    });
  });

  group('upgrade with existing records', () {
    setUp(() async {
      await db.insertCycle(
        CycleEntry(startDate: DateTime(2026, 1, 1), duration: 5),
      );
      await db.insertCycle(
        CycleEntry(startDate: DateTime(2026, 1, 29), duration: 5),
      );
    });

    testWidgets('asks rather than assuming, and says the data was kept',
        (tester) async {
      await pumpGate(tester);

      expect(find.text('One thing first'), findsOneWidget);
      expect(find.textContaining('they have been kept'), findsOneWidget);
      expect(find.byType(RootScaffold), findsNothing);
      // The destructive route is offered, not hidden behind a link.
      expect(find.text('Delete the records instead'), findsOneWidget);
    });

    testWidgets('acknowledging keeps the history and opens the app',
        (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('We have talked about it'));
      await pumpUntil(tester, () => find.byType(RootScaffold).evaluate().isNotEmpty,
          reason: 'the app to open');

      expect(find.byType(RootScaffold), findsOneWidget);
      expect(await tester.runAsync(db.countCycles), 2,
          reason: 'the upgrade must never destroy existing records');

      final records = await tester.runAsync(db.getConsentRecords);
      expect(records!.single.action.name, 'acknowledgedLegacy');
    });

    testWidgets('deleting instead wipes the history', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('Delete the records instead'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      // Bounded pumps, never pumpAndSettle: the button shows a progress
      // indicator while the wipe runs, and an indeterminate spinner never
      // settles under the test clock.
      await pumpUntil(
        tester,
        () => find.textContaining('Consent was withdrawn').evaluate().isNotEmpty,
        reason: 'the gate to report the withdrawal',
      );

      expect(await tester.runAsync(db.countCycles), 0);
      // Still no way into the app.
      expect(find.byType(RootScaffold), findsNothing);
      expect(find.textContaining('Consent was withdrawn'), findsOneWidget);
    });
  });

  group('settings privacy card', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      // Tall enough that the whole Settings list builds: a ListView only
      // creates the children in its viewport, so a short surface would make
      // this test pass or fail depending on the scroll position.
      tester.view.physicalSize = const Size(600, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      late ConsentProvider consent;
      late SettingsProvider settings;
      late CycleProvider cycles;

      await tester.runAsync(() async {
        consent = ConsentProvider(database: db);
        settings = SettingsProvider(database: db);
        cycles = CycleProvider(database: db);
        await consent.load();
        await settings.load();
        await cycles.load();
        await consent.grant(method: ConsentMethod.setup);
        await db.insertCycle(
          CycleEntry(startDate: DateTime(2026, 1, 1), duration: 5),
        );
        await cycles.load();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DatabaseHelper>.value(value: db),
            ChangeNotifierProvider<ConsentProvider>.value(value: consent),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<CycleProvider>.value(value: cycles),
            // Settings links to preferences, symptoms and reminders, each of
            // which reads its own provider.
            ChangeNotifierProvider<PreferencesProvider>(
              create: (_) => PreferencesProvider(database: db)..load(),
            ),
            ChangeNotifierProvider<SymptomsProvider>(
              create: (_) => SymptomsProvider(database: db)..load(),
            ),
            ChangeNotifierProvider<RemindersProvider>(
              create: (_) => RemindersProvider(database: db)..load(),
            ),
            ChangeNotifierProvider<UpdateProvider>(
              create: (_) => UpdateProvider(),
            ),
            Provider<BackupService>(create: (_) => BackupService(database: db)),
            Provider<NotificationRescheduler>(
              create: (_) => _NoopRescheduler(),
            ),
          ],
          child: MaterialApp(
            theme: ElaraTheme.light(),
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }

    // Settings is a hub of rows; each subject now has its own page.
    Future<void> openPrivacy(WidgetTester tester) async {
      await tester.tap(find.text('Privacy and data'));
      await tester.pumpAndSettle();
      // The page title repeats the row's name, so there are two of them.
      expect(find.text('Consent'), findsOneWidget);
    }

    testWidgets('shows consent, privacy, backup and deletion', (tester) async {
      await pumpSettings(tester);
      await openPrivacy(tester);

      expect(find.text('Privacy and data'), findsOneWidget);
      expect(find.text('Consent'), findsOneWidget);
      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('Show cycle details in reminders'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(
        find.text('Withdraw consent and delete everything'),
        findsOneWidget,
      );
    });

    testWidgets('reminder details are off by default', (tester) async {
      await pumpSettings(tester);
      await openPrivacy(tester);

      // The switch that governs what appears on a lock screen must start off.
      final toggle = tester.widget<Switch>(
        find.byWidgetPredicate(
          (w) => w is Switch && w.value == false,
        ).first,
      );
      expect(toggle.value, isFalse);
      expect(
        find.text('Open Elara for today\u2019s note.'),
        findsNothing,
      );
      expect(
        find.textContaining('Reminders say only that there is a note waiting'),
        findsOneWidget,
      );
    });

    testWidgets('deleting everything requires typing a word', (tester) async {
      await pumpSettings(tester);
      await openPrivacy(tester);

      // The sentence is a label above the control; the control itself is the
      // short, filled, destructive button.
      expect(
        find.text('Withdraw consent and delete everything'),
        findsOneWidget,
      );
      expect(find.text('Delete everything'), findsOneWidget);
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();

      expect(find.text('Withdraw consent?'), findsOneWidget);

      // The confirm button is inert until the word is typed.
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Withdraw'),
      );
      expect(confirm.onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'withdraw');
      await tester.pump();

      final enabled = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Withdraw'),
      );
      expect(enabled.onPressed, isNotNull);
    });
  });
}

class _NoopRescheduler implements NotificationRescheduler {
  @override
  Future<void> reschedule() async {}
}
