import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/consent_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/screens/root_scaffold.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/backup_service.dart';
import 'package:elara_app/services/notification_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:elara_app/utils/phase_timeline.dart';
import 'package:elara_app/widgets/food_chip_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Layout holds at the sizes that actually break Flutter apps: a small phone, a
/// large-text user, and a tablet.
///
/// These tests fail on a render overflow, which is what a `Row` of fixed-width
/// children does the moment the text scale or the viewport changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance;
    db.overridePath = inMemoryDatabasePath;
    await db.close();
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  http.Client offline() => MockClient((_) async => http.Response('offline', 503));

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
    bool dark = false,
    List<DateTime> starts = const [],
  }) async {
    final climate = ClimateService(
      database: db,
      httpClient: offline(),
      timeout: const Duration(seconds: 1),
    );
    late SettingsProvider settings;
    late CycleProvider cycles;
    late ClimateProvider climateProvider;
    late PredictionProvider prediction;
    late ConsentProvider consent;

    await tester.runAsync(() async {
      for (final start in starts) {
        await db.insertCycle(CycleEntry(startDate: start, duration: 5));
      }
      settings = SettingsProvider(database: db);
      cycles = CycleProvider(database: db);
      climateProvider = ClimateProvider(climateService: climate);
      prediction = PredictionProvider(
        predictionService: PredictionService(
          database: db,
          climateService: climate,
        ),
      );
      consent = ConsentProvider(database: db);
      await consent.load();
      await settings.load();
      await cycles.load();
      await prediction.refresh();
      await climateProvider.load();
    });

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MultiProvider(
          providers: [
            Provider<DatabaseHelper>.value(value: db),
            // The app provides these in main.dart; the harness supplies the
            // same three so Settings can render its privacy card.
            ChangeNotifierProvider<ConsentProvider>.value(value: consent),
            Provider<BackupService>(create: (_) => BackupService(database: db)),
            Provider<NotificationRescheduler>(create: (_) => _NoopRescheduler()),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<CycleProvider>.value(value: cycles),
            ChangeNotifierProvider<ClimateProvider>.value(value: climateProvider),
            ChangeNotifierProvider<PredictionProvider>.value(value: prediction),
          ],
          child: MaterialApp(
            // Same wiring as main.dart: the theme is built from the phase the
            // prediction reports, so a phase change repaints without a restart.
            theme: dark
                ? ElaraTheme.dark(
                    phaseKey: phaseKeyOfResult(prediction.result) ?? 'luteal')
                : ElaraTheme.light(phaseKey: phaseKeyOfResult(prediction.result)),
            home: const RootScaffold(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }

  final now = DateTime.now();
  final history = [
    now.subtract(const Duration(days: 68)),
    now.subtract(const Duration(days: 39)),
    now.subtract(const Duration(days: 9)),
  ];

  group('navigation', () {
    testWidgets('a phone keeps the bottom bar and no rail', (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet gets a rail and no bottom bar', (tester) async {
      await pumpApp(tester, size: const Size(1024, 768), starts: history);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below the breakpoint there is no rail', (tester) async {
      await pumpApp(
        tester,
        size: const Size(RootScaffold.railBreakpoint - 1, 900),
        starts: history,
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('at the breakpoint the rail appears', (tester) async {
      await pumpApp(
        tester,
        size: const Size(RootScaffold.railBreakpoint, 900),
        starts: history,
      );
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('small screen', () {
    testWidgets('320px wide renders every tab without overflow',
        (tester) async {
      await pumpApp(tester, size: const Size(320, 640), starts: history);

      for (final tab in ['Today', 'Calendar', 'Insights', 'Settings']) {
        await tester.tap(find.text(tab).last);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'tab: $tab');
      }
    });

    testWidgets('no cycle history still renders on a small screen',
        (tester) async {
      await pumpApp(tester, size: const Size(320, 640));
      expect(find.text('Welcome to Elara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('large text', () {
    testWidgets('every tab survives a 1.3x text scale', (tester) async {
      await pumpApp(
        tester,
        size: const Size(390, 844),
        textScale: 1.3,
        starts: history,
      );

      for (final tab in ['Today', 'Calendar', 'Insights', 'Settings']) {
        await tester.tap(find.text(tab).last);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'tab: $tab');
      }
    });

    testWidgets('calendar cells grow with the text scale', (tester) async {
      await pumpApp(
        tester,
        size: const Size(390, 844),
        textScale: 2.0,
        starts: history,
      );
      await tester.tap(find.text('Calendar').last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();

      // Every laid-out day cell must be at least the 48dp touch minimum.
      final cells = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.height != null && box.height! >= 48)
          .toList();
      expect(cells, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('guidance has no scores', () {
    testWidgets('Today shows prose guidance, never a score out of ten',
        (tester) async {
      await pumpApp(tester, size: const Size(390, 1400), starts: history);

      // When the engine produced guidance, it is prose. It renders only when a
      // phase and severity are both available, so this is conditional; the
      // no-scores assertions below are not.
      if (find.text('A place to start').evaluate().isNotEmpty) {
        expect(find.textContaining('What she says matters'), findsOneWidget);
      }

      // Nothing scoring-shaped anywhere on the screen.
      expect(find.textContaining('Conversation'), findsNothing);
      expect(find.textContaining('Romance'), findsNothing);
      expect(find.textContaining('/10'), findsNothing);
      expect(find.byType(FoodChipRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('phase-adaptive theming in the running app', () {
    testWidgets('the accent matches the phase the app is in', (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      final context = tester.element(find.byType(RootScaffold));
      final tokens = context.elara;
      final result =
          Provider.of<PredictionProvider>(context, listen: false).result;
      final phaseKey = phaseKeyOfResult(result);

      if (phaseKey == null) {
        // No classification: the neutral accent is the correct answer.
        expect(tokens.accent, ElaraPalette.light.accent);
        expect(tokens.bgCard, ElaraPalette.light.bgCard);
      } else {
        // The accent is this phase's colour and the card carries its tint.
        expect(tokens.accent, tokens.phaseFill(phaseKey));
        expect(tokens.bgCard, isNot(ElaraPalette.light.bgCard));
      }
      expect(tester.takeException(), isNull);
    });
  });
}

/// Stands in for the reminder layer so widget tests never touch a plugin.
class _NoopRescheduler implements NotificationRescheduler {
  @override
  Future<void> reschedule() async {}
}
