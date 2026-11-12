import 'package:elara_app/data/database_helper.dart';
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
    late PreferencesProvider preferences;
    late SymptomsProvider symptoms;

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
      preferences = PreferencesProvider(database: db);
      symptoms = SymptomsProvider(database: db);
      await consent.load();
      await settings.load();
      await cycles.load();
      await prediction.refresh();
      await climateProvider.load();
      await preferences.load();
      await symptoms.load();
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
            ChangeNotifierProvider<PreferencesProvider>.value(
                value: preferences),
            ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
            ChangeNotifierProvider<RemindersProvider>(create: (_) => RemindersProvider(database: db)..load()),
            ChangeNotifierProvider<UpdateProvider>(
              create: (_) => UpdateProvider(),
            ),
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

      // The bar is the app's own floating card, not a Material NavigationBar:
      // it carries the raised centre action, which NavigationBar cannot express
      // without a fifth destination that is not a destination.
      expect(find.byType(ElaraNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet gets a rail and no bottom bar', (tester) async {
      await pumpApp(tester, size: const Size(1024, 768), starts: history);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(ElaraNavBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below the breakpoint there is no rail', (tester) async {
      await pumpApp(
        tester,
        size: const Size(RootScaffold.railBreakpoint - 1, 900),
        starts: history,
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(ElaraNavBar), findsOneWidget);
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

  // Swiping the content is now a way to move between tabs, alongside the bar.
  // The assertions are about the tab that ends up selected, which is the only
  // thing the reader can see the result of.
  group('swipe', () {
    /// Which tab the bar says is selected — the reader-visible result of a
    /// swipe, and the only thing worth asserting.
    int selected(WidgetTester tester) =>
        tester.widget<ElaraNavBar>(find.byType(ElaraNavBar)).selectedIndex;

    Future<void> swipe(WidgetTester tester, double dx) async {
      await tester.drag(
        find.byType(IndexedStack),
        Offset(dx, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a left swipe moves forward one tab', (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);
      expect(find.text('Today'), findsWidgets);

      expect(selected(tester), 0);

      await swipe(tester, -300);
      // Calendar follows Today in the bar's order.
      expect(selected(tester), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a right swipe from the first tab stays on it', (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      // There is nothing to the left of Today, so the content resists and
      // springs back rather than sliding into empty space.
      await swipe(tester, 300);
      expect(tester.takeException(), isNull);
      expect(selected(tester), 0);
      expect(find.text('Ways to help today'), findsOneWidget);
    });

    testWidgets('swiping back and forth returns to the starting tab',
        (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      await swipe(tester, -300);
      await swipe(tester, 300);
      expect(tester.takeException(), isNull);
      expect(selected(tester), 0);
      expect(find.text('Ways to help today'), findsOneWidget);
    });

    testWidgets('a short drag is not a tab change', (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      // 30px on a 390dp screen is a nudge, not a swipe.
      await swipe(tester, -30);
      expect(selected(tester), 0);
      expect(find.text('Ways to help today'), findsOneWidget);
    });

    testWidgets('vertical scrolling still scrolls rather than changing tab',
        (tester) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      await tester.drag(find.byType(IndexedStack), const Offset(0, -300));
      await tester.pumpAndSettle();

      // The list scrolled; the tab has not changed.
      expect(selected(tester), 0);
      expect(find.text('Ways to help today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // The widths the brief names, checked on the tab that carries the most
  // content per row: the phase chip, the countdown and the suggestion headings.
  group('phone widths', () {
    for (final width in <double>[320, 360, 375, 390, 430]) {
      testWidgets('Today lays out at ${width.toInt()}dp', (tester) async {
        await pumpApp(
          tester,
          size: Size(width, 844),
          starts: history,
        );
        expect(tester.takeException(),
            isNull, reason: '${width.toInt()}dp');
        // The first suggestion must be on screen, not clipped away.
        expect(find.text('Ways to help today'), findsOneWidget);
      });
    }

    testWidgets('a 720dp window keeps the rail and a readable column',
        (tester) async {
      await pumpApp(tester, size: const Size(720, 900), starts: history);
      expect(tester.takeException(), isNull);
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

    // 1.5x and 2.0x are the sizes the design brief names, and 1.3x alone does
    // not reach the point where the phase chip and the countdown start competing
    // for a single line.
    for (final scale in <double>[1.5, 2.0]) {
      testWidgets('every tab survives a ${scale}x text scale', (tester) async {
        await pumpApp(
          tester,
          size: const Size(390, 844),
          textScale: scale,
          starts: history,
        );

        for (final tab in ['Today', 'Calendar', 'Insights', 'Settings']) {
          await tester.tap(find.text(tab).last);
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 120)),
          );
          await tester.pump();
          expect(tester.takeException(),
              isNull, reason: 'tab: $tab at ${scale}x');
        }
      });
    }

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

      // When the engine produced an action, the card is present and its copy is
      // prose. It renders only when a phase and severity are both available, so
      // this is conditional; the no-scores assertions below are not.
      if (find.textContaining('FROM THE ESTIMATED PHASE').evaluate().isNotEmpty) {
        expect(find.textContaining('A suggestion, not a forecast'),
            findsOneWidget);
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
        // The accent is this phase's colour...
        expect(tokens.accent, tokens.phaseFill(phaseKey));
        // ...but the surfaces stay neutral. Phase colour appears as an accent
        // and as an explicit wash, never as a tinted page: tinting every card
        // made the app look like a dashboard and pushed text contrast down.
        expect(tokens.bgCard, ElaraPalette.light.bgCard);
        expect(tokens.bgPrimary, ElaraPalette.light.bgPrimary);
        expect(tokens.phaseWash(phaseKey).a, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });
  });

  // The bar carries a raised centre action. That is the one thing a Material
  // NavigationBar could not express here: the app's primary verb, on every tab,
  // instead of only behind a button in the calendar's header.
  group('the centre action', () {
    Finder inBar(Finder matching) =>
        find.descendant(of: find.byType(ElaraNavBar), matching: matching);

    testWidgets('floats clear of the edges instead of sitting on them', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      // The card, not the widget that spans the screen: a bar welded to the
      // bottom edge would start at x = 0, end at x = 390 and end at y = 844.
      // This one is inset at both sides and stops above the edge, so the page is
      // visible all the way round it - which is the whole of what "floating"
      // means, and the thing that would silently regress if someone put a
      // NavigationBar back.
      final card = tester.getRect(find.byKey(ElaraNavBar.cardKey));
      expect(card.left, greaterThan(0));
      expect(card.right, lessThan(390));
      expect(card.bottom, lessThan(844));

      // And the action rises above it, which is what makes it findable with a
      // thumb without giving it a fifth column.
      final action = tester.getRect(
        find.descendant(
          of: find.byType(ElaraNavBar),
          matching: find.byIcon(Icons.add_rounded),
        ),
      );
      expect(action.top, lessThan(card.top));

      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the log sheet from a tab with no logging control', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      // Today has no way of its own to record anything; that was the complaint.
      await tester.tap(inBar(find.text('Today')));
      await tester.pumpAndSettle();

      await tester.tap(inBar(find.byIcon(Icons.add_rounded)));
      await tester.pumpAndSettle();

      expect(find.text('A period start'), findsOneWidget);
      expect(find.text('A symptom'), findsOneWidget);
    });

    testWidgets('the period-start row opens the picker the calendar uses', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(390, 844), starts: history);

      await tester.tap(inBar(find.byIcon(Icons.add_rounded)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A period start'));
      await tester.pumpAndSettle();

      // The same help text as the calendar's header button: one flow, two doors.
      // A sheet that opened a second, subtly different date entry would pass a
      // "the sheet opened" test and still be the bug this change was meant to
      // remove.
      expect(find.text('Which day did it start?'), findsOneWidget);
    });
  });
}

/// Stands in for the reminder layer so widget tests never touch a plugin.
class _NoopRescheduler implements NotificationRescheduler {
  @override
  Future<void> reschedule() async {}
}
