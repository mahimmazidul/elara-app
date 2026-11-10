import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/screens/calendar/calendar_screen.dart';
import 'package:elara_app/screens/insights/cycle_length_page.dart';
import 'package:elara_app/screens/insights/insights_screen.dart';
import 'package:elara_app/screens/today/today_screen.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:elara_app/widgets/phase_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Widget tests for the three data-driven screens.
///
/// The screens read through the real providers, over the real schema, with the
/// real prediction engine — only the weather client is replaced, because a test
/// must not touch the network. That means these tests exercise the same paths a
/// first launch does, including the empty-database case that is easiest to get
/// wrong.
///
/// sqflite runs on a background isolate, so every asynchronous step happens
/// inside [WidgetTester.runAsync]; awaiting database work under the default fake
/// clock would deadlock, since nothing advances real time.
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

  /// Answers every request with a server error, which is how the app behaves
  /// offline: the climate service falls back to its seasonal baseline.
  http.Client offlineClient() =>
      MockClient((_) async => http.Response('offline', 503));

  /// Seeds the database and returns a provider graph that has already loaded.
  ///
  /// Must be called inside [WidgetTester.runAsync].
  Future<_Graph> buildGraph({required List<DateTime> starts}) async {
    for (final start in starts) {
      await db.insertCycle(CycleEntry(startDate: start, duration: 5));
    }

    final climateService = ClimateService(
      database: db,
      httpClient: offlineClient(),
      timeout: const Duration(seconds: 1),
    );
    final settings = SettingsProvider(database: db);
    final cycles = CycleProvider(database: db);
    final preferences = PreferencesProvider(database: db);
    final symptoms = SymptomsProvider(database: db);
    final climate = ClimateProvider(climateService: climateService);
    final prediction = PredictionProvider(
      predictionService: PredictionService(
        database: db,
        climateService: climateService,
      ),
    );

    await settings.load();
    await cycles.load();
    await preferences.load();
    await symptoms.load();
    await prediction.refresh();
    await climate.load();

    return _Graph(
      settings: settings,
      cycles: cycles,
      preferences: preferences,
      symptoms: symptoms,
      climate: climate,
      prediction: prediction,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    _Graph graph,
    Widget screen,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          ChangeNotifierProvider<SettingsProvider>.value(value: graph.settings),
          ChangeNotifierProvider<CycleProvider>.value(value: graph.cycles),
          ChangeNotifierProvider<PreferencesProvider>.value(
              value: graph.preferences),
          ChangeNotifierProvider<SymptomsProvider>.value(value: graph.symptoms),
          ChangeNotifierProvider<RemindersProvider>(
              create: (_) => RemindersProvider(database: db)..load(),
          ),
          ChangeNotifierProvider<RemindersProvider>(create: (_) => RemindersProvider(database: db)..load()),
          ChangeNotifierProvider<UpdateProvider>(
            create: (_) => UpdateProvider(),
          ),
          ChangeNotifierProvider<ClimateProvider>.value(value: graph.climate),
          ChangeNotifierProvider<PredictionProvider>.value(
              value: graph.prediction),
        ],
        child: MaterialApp(
          theme: ElaraTheme.light(),
          home: Scaffold(body: SafeArea(child: screen)),
        ),
      ),
    );
    // One frame, then let any pending real I/O (screen-level database reads)
    // finish before the tree is inspected.
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }

  // ------------------------------------------------------------------ Today --

  group('Today screen', () {
    testWidgets('renders without crashing when no cycle is recorded',
        (tester) async {
      final graph = await tester.runAsync(() => buildGraph(starts: const []));
      await pumpScreen(tester, graph!, const TodayScreen());

      expect(tester.takeException(), isNull);
      // With no history the screen offers the first step instead of inventing a
      // phase or a countdown.
      expect(find.text('Welcome to Elara'), findsOneWidget);
      expect(find.textContaining('Everything stays on this phone'), findsOneWidget);
    });

    testWidgets('renders without crashing with a single recorded cycle',
        (tester) async {
      final started = DateTime.now().subtract(const Duration(days: 9));
      final graph = await tester.runAsync(() => buildGraph(starts: [started]));
      await pumpScreen(tester, graph!, const TodayScreen());

      expect(tester.takeException(), isNull);
      // The onboarding prompt is gone: there is history now.
      expect(find.text('Welcome to Elara'), findsNothing);
      // Whatever the engine can offer from one data point, the screen shows
      // something real: either the phase dial, or the explicit "not enough
      // history" explanation. It never renders a blank frame.
      final showsPhase = find.byType(PhaseDial).evaluate().isNotEmpty;
      final explains = find.text('Not enough history yet').evaluate().isNotEmpty;
      expect(showsPhase || explains, isTrue);
    });
  });

  // --------------------------------------------------------------- Calendar --

  group('Calendar screen', () {
    testWidgets('renders and colours days by predicted phase', (tester) async {
      // Two starts 28 days apart, the newer one five days back, so the visible
      // month spans a menstrual run and the follicular days after it.
      final now = DateTime.now();
      final graph = await tester.runAsync(() => buildGraph(starts: [
            DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 33)),
            DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 5)),
          ]));
      await pumpScreen(tester, graph!, const CalendarScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('Calendar'), findsOneWidget);
      // A forecast exists, so the grid is coloured rather than bare dates.
      expect(find.text('Coloured by predicted phase'), findsOneWidget);

      // Collect every fill used in the grid and check that at least two of the
      // four phase washes appear: one phase alone would not prove the grid
      // distinguishes phases.
      final tokens = ElaraTheme.light().extension<ElaraTokens>()!;
      final phaseWashes = {
        'menstrual': tokens.phaseWash('menstrual', opacity: 0.30),
        'follicular': tokens.phaseWash('follicular', opacity: 0.30),
        'ovulatory': tokens.phaseWash('ovulatory', opacity: 0.30),
        'luteal': tokens.phaseWash('luteal', opacity: 0.30),
      };

      final usedColors = <Color>{};
      for (final container
          in tester.widgetList<Container>(find.byType(Container))) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration && decoration.color != null) {
          usedColors.add(decoration.color!);
        }
      }

      final phasesShown = phaseWashes.entries
          .where((entry) => usedColors.contains(entry.value))
          .map((entry) => entry.key)
          .toList();

      expect(
        phasesShown.length,
        greaterThanOrEqualTo(2),
        reason: 'expected two or more phase colours in the grid, saw $phasesShown',
      );
    });

    testWidgets('falls back to plain dates with no history', (tester) async {
      final graph = await tester.runAsync(() => buildGraph(starts: const []));
      await pumpScreen(tester, graph!, const CalendarScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('Log a period start to see phases'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------- Insights --

  group('Insights screen', () {
    testWidgets('the hub summarises before it makes you open anything',
        (tester) async {
      final started = DateTime.now().subtract(const Duration(days: 12));
      final graph = await tester.runAsync(() => buildGraph(starts: [started]));
      await pumpScreen(tester, graph!, const InsightsScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('Insights'), findsOneWidget);

      // Three subjects, each carrying the line that says whether it needs
      // opening. The charts themselves are behind the rows now.
      expect(find.text('Cycle length'), findsOneWidget);
      expect(find.text('How steady it is'), findsOneWidget);
      expect(find.text('How the prediction was made'), findsOneWidget);
      expect(find.text('Heat and the cycle'), findsOneWidget);

      // One recorded start and no completed cycle: the summary says so rather
      // than quoting a mean of one number.
      expect(find.text('No completed cycles yet'), findsOneWidget);
      expect(find.text('Needs two completed cycles'), findsOneWidget);
    });

    testWidgets('the cycle-length page shows the chart and its empty state',
        (tester) async {
      final started = DateTime.now().subtract(const Duration(days: 12));
      final graph = await tester.runAsync(() => buildGraph(starts: [started]));
      await pumpScreen(tester, graph!, const CycleLengthPage());

      expect(tester.takeException(), isNull);
      // No completed cycle length exists yet, so the chart says so plainly
      // instead of drawing an empty axis.
      expect(find.text('Not enough cycles yet'), findsOneWidget);
      expect(
        find.text('Standard deviation needs at least two completed cycles.'),
        findsOneWidget,
      );
    });

    testWidgets('a row opens its page', (tester) async {
      final now = DateTime.now();
      final graph = await tester.runAsync(() => buildGraph(starts: [
            now.subtract(const Duration(days: 59)),
            now.subtract(const Duration(days: 30)),
            now.subtract(const Duration(days: 2)),
          ]));
      await pumpScreen(tester, graph!, const InsightsScreen());

      await tester.tap(find.text('Cycle length'));
      await tester.pumpAndSettle();

      // The page repeats the subject as its title and carries the explanation
      // of what the spread does to the forecast, below the two charts.
      expect(find.text('Cycle length'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('What this does to the forecast'),
        240,
      );
      expect(find.text('What this does to the forecast'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty database still renders the hub', (tester) async {
      final graph = await tester.runAsync(() => buildGraph(starts: const []));
      await pumpScreen(tester, graph!, const InsightsScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('No completed cycles yet'), findsOneWidget);
    });
  });
}

/// The providers under test, bundled so a test can assert on state as well as
/// on the rendered tree.
class _Graph {
  _Graph({
    required this.settings,
    required this.cycles,
    required this.preferences,
    required this.symptoms,
    required this.climate,
    required this.prediction,
  });

  final SettingsProvider settings;
  final CycleProvider cycles;
  final PreferencesProvider preferences;
  final SymptomsProvider symptoms;
  final ClimateProvider climate;
  final PredictionProvider prediction;
}
