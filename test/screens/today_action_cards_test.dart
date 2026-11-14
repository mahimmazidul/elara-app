import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/data/models/preference.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/today/action_cards.dart';
import 'package:elara_app/screens/today/today_screen.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:elara_core/elara_core.dart' as core;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression tests for the action card, the part of Today that turns an
/// estimated phase into something concrete to do.
///
/// These exist because the care recommender was added *beside* the action card
/// rather than on top of it, and it is easy for a later refactor to quietly drop
/// either half. The assertions are deliberately about what a person can see:
/// the prompt, the food ideas, and the absence of the numerical scores that Elara
/// no longer shows.
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

  http.Client offlineClient() =>
      MockClient((_) async => http.Response('offline', 503));

  /// The same action elara-core's `ActionEngine` returns for the first days of a
  /// period: two prompting cards and a short food list.
  core.ActionResult sampleAction() => core.ActionResult(
        conversationScore: 1,
        romanceScore: 2,
        foodSuggestions: const ['Complex carbohydrates', 'Iron-rich foods'],
        cards: const [
          core.ActionCard(
            title: 'Offer practical support',
            body: 'Ask what would feel welcome; preferences can change.',
          ),
          core.ActionCard(title: 'Food idea', body: 'Complex carbohydrates'),
        ],
      );

  Future<void> pumpCard(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? ElaraTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ActionCards', () {
    testWidgets('renders the prompt, the food ideas and the caveat',
        (tester) async {
      await pumpCard(
        tester,
        ActionCards(action: sampleAction(), phaseKey: 'menstrual'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Offer practical support'), findsOneWidget);
      expect(
        find.text('Ask what would feel welcome; preferences can change.'),
        findsOneWidget,
      );
      expect(find.text('Complex carbohydrates'), findsOneWidget);
      expect(find.text('Iron-rich foods'), findsOneWidget);
      expect(find.textContaining('A suggestion, not a forecast'), findsOneWidget);
      // The block is labelled as phase-derived, not as a fact about her.
      expect(find.textContaining('FROM THE ESTIMATED PHASE'), findsOneWidget);
    });

    testWidgets('never renders the conversation or romance scores',
        (tester) async {
      await pumpCard(
        tester,
        ActionCards(action: sampleAction(), phaseKey: 'menstrual'),
      );

      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();

      // Not the numbers, and not the words either: the whole idea of scoring
      // this was removed, so an empty bar or a label would be just as wrong.
      expect(text, isNot(contains('conversation')));
      expect(text, isNot(contains('romance')));
      expect(text, isNot(contains('/10')));
    });

    testWidgets('explains itself when the phase cannot be classified',
        (tester) async {
      await pumpCard(
        tester,
        const ActionCards(action: null, phaseKey: 'unknown'),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Phase guidance appears'), findsOneWidget);
      // No food chips, because there is no rule to draw them from.
      expect(find.text('Complex carbohydrates'), findsNothing);
    });

    testWidgets('uses the phase accent, not a tinted background',
        (tester) async {
      await pumpCard(
        tester,
        ActionCards(action: sampleAction(), phaseKey: 'ovulatory'),
      );
      final tokens = ElaraTheme.light().extension<ElaraTokens>()!;
      final overline = tester.widget<Text>(
        find.textContaining('FROM THE ESTIMATED PHASE'),
      );
      expect(overline.style?.color, tokens.phaseText('ovulatory'));
    });
  });

  group('Today', () {
    Future<void> seed(List<DateTime> starts) async {
      for (final start in starts) {
        await db.insertCycle(CycleEntry(startDate: start, duration: 5));
      }
    }

    testWidgets('renders the action card alongside the care suggestions',
        (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final graph = await tester.runAsync(() async {
        await seed([
          today.subtract(const Duration(days: 33)),
          today.subtract(const Duration(days: 2)),
        ]);

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

        // Something she said, so the evidence block has content of its own and
        // the two halves of the section can be told apart on screen.
        await preferences.addHerAnswer(
          category: PreferenceCategory.food,
          value: 'khichuri',
          share: true,
        );

        return (
          settings: settings,
          cycles: cycles,
          preferences: preferences,
          symptoms: symptoms,
          climate: climate,
          prediction: prediction,
        );
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DatabaseHelper>.value(value: db),
            ChangeNotifierProvider<SettingsProvider>.value(
                value: graph!.settings),
            ChangeNotifierProvider<CycleProvider>.value(value: graph.cycles),
            ChangeNotifierProvider<PreferencesProvider>.value(
                value: graph.preferences),
            ChangeNotifierProvider<SymptomsProvider>.value(
                value: graph.symptoms),
            ChangeNotifierProvider<RemindersProvider>(
                create: (_) => RemindersProvider(database: db)..load(),
            ),
            ChangeNotifierProvider<UpdateProvider>(
              create: (_) => UpdateProvider(),
            ),
            ChangeNotifierProvider<ClimateProvider>.value(value: graph.climate),
            ChangeNotifierProvider<PredictionProvider>.value(
                value: graph.prediction),
          ],
          child: MaterialApp(
            theme: ElaraTheme.light(),
            home: const Scaffold(body: SafeArea(child: TodayScreen())),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      // The section heading is present, and the phase guide for the active
      // phase is rendered inline below the hero instead of behind a link.
      expect(find.text('Ways to help today'), findsOneWidget);
      expect(find.text('ESTIMATED FOR TODAY'), findsOneWidget);

      // Her answer is rendered as the first thing to act on.
      expect(find.textContaining('khichuri'), findsWidgets);

      // And the action card is rendered too: the phase prompt from
      // elara-core's ActionEngine, with its basis line.
      expect(find.byType(ActionCards), findsOneWidget);
      expect(
        find.textContaining('FROM THE ESTIMATED PHASE'),
        findsOneWidget,
      );

      // No scoring anywhere on the screen.
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(text, isNot(contains('romance')));
      expect(text, isNot(contains('conversation score')));

      // The guide is already on screen under the estimate: its kitchen ideas
      // are visible with nothing to tap to reach them.
      expect(find.textContaining('From the kitchen, if she wants'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
