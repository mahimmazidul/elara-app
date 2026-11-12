// Generates the screenshots used in the README and on the landing page.
//
// These are renders of the real widget tree, not mockups: the same providers,
// the same theme, the same bundled fonts, seeded with a plausible history. Run
// with
//
//   flutter test tool/screenshots/screenshots_test.dart --update-goldens
//
// which writes PNGs into docs/screenshots/. It lives outside test/ so that a
// normal `flutter test` run never regenerates them or compares them.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/climate_snapshot.dart';
import 'package:elara_app/data/models/cycle_mode.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/data/models/preference.dart';
import 'package:elara_app/data/models/symptom.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/data/models/consent_record.dart';
import 'package:elara_app/providers/consent_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/root_scaffold.dart';
import 'package:elara_app/utils/phase_timeline.dart';
import 'package:elara_app/services/backup_service.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/notification_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pixel 7 class logical size, rasterised at 3x for a 1170x2532 PNG.
const Size _logicalSize = Size(390, 844);

/// A small tablet in landscape, wide enough to show the navigation rail.
const Size _tabletSize = Size(1024, 768);
const double _pixelRatio = 3;

final GlobalKey _frameKey = GlobalKey();

/// Locates the SDK's icon font, which a headless render must be given because
/// there is no system font to fall back on.
String? _findMaterialIcons() {
  final fromEnvironment = Platform.environment['FLUTTER_ROOT'];
  // Derived from the running Dart VM: <sdk>/bin/cache/dart-sdk/bin/dart.
  final fromExecutable = Platform.resolvedExecutable.split('/bin/').first;
  final roots = <String>[?fromEnvironment, fromExecutable];

  for (final root in roots) {
    final candidate =
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

/// Plausible late-monsoon Dhaka weather, so the strips and charts show real
/// numbers instead of the seasonal estimate.
String _meteoBody(DateTime day) => jsonEncode({
  'latitude': 23.81,
  'longitude': 90.41,
  'daily': {
    'time': [
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
    ],
    'temperature_2m_mean': [31.2],
    'relative_humidity_2m_mean': [82],
    'sunshine_duration': [19800],
    'precipitation_sum': [1.2],
  },
});

String get _aqBody => jsonEncode({
  'results': [
    {
      'country': {'code': 'BD', 'name': 'Bangladesh'},
      'measurements': [
        {
          'parameter': {'name': 'pm25'},
          'value': 46.0,
        },
      ],
    },
  ],
});

http.Client _network() => MockClient((request) async {
  if (request.url.host == 'api.open-meteo.com') {
    return http.Response(_meteoBody(DateTime.now()), 200);
  }
  if (request.url.host == 'api.openaq.org') {
    return http.Response(_aqBody, 200);
  }
  return http.Response('not found', 404);
});

/// Deterministic settling: a frame, then real time for the sqflite reads the
/// screens kick off on init, then another frame. Never pumpAndSettle, since a
/// loading spinner animates forever and would time the test out.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  // Advance the *fake* clock past the longest animation in the app. The
  // entrance fade is 200 ms and the phase chip's colour move is 200 ms, and
  // `pump(Duration.zero)` does not move either: the screenshots in docs/ used
  // to show the Today heading at about 25% opacity and the phase chip's fill
  // half-way between its old colour and its new one, because the capture was
  // taken a few frames into the fade. Letting the animation finish makes the
  // image show the screen a person actually sees.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // The four bundled weights. A headless render has no system fonts, so
    // every family the app draws with has to be loaded by hand here.
    await _loadFont('Hind Siliguri', [
      'assets/fonts/HindSiliguri-Regular.ttf',
      'assets/fonts/HindSiliguri-Medium.ttf',
      'assets/fonts/HindSiliguri-SemiBold.ttf',
      'assets/fonts/HindSiliguri-Bold.ttf',
    ]);
    // The incumbent family, kept only so that the font comparison can still
    // render the screens in it. The app does not ship it.
    await _loadFont('DM Sans', [
      'tool/fonts/comparison/assets/DMSans-Regular.ttf',
      'tool/fonts/comparison/assets/DMSans-Medium.ttf',
      'tool/fonts/comparison/assets/DMSans-Bold.ttf',
    ]);
    // Icons come from the SDK, since a headless test has no system icon font.
    // The path is resolved rather than hardcoded, so this runs on a developer
    // machine and on a CI runner without edits.
    final icons = _findMaterialIcons();
    if (icons == null) {
      throw StateError(
        'MaterialIcons-Regular.otf not found. Set FLUTTER_ROOT to the Flutter '
        'SDK, or run `flutter precache --universal`.',
      );
    }
    // The Bengali fallback the incumbent family used, loaded so that the
    // font comparison can still render the screens in it.
    await _loadFont('Noto Sans Bengali', [
      'tool/fonts/comparison/assets/NotoSansBengali-Subset.ttf',
    ]);
    await _loadFont('MaterialIcons', [icons]);
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

  /// Fictional, deliberately unremarkable preferences and one reported symptom.
  ///
  /// The home screen is more honest with real inputs: a suggestion with a
  /// stated source ("She told you this") reads very differently from one the
  /// app guessed, and the README should show the former.
  Future<void> seedPreferences() async {
    final now = DateTime.now();
    await db.insertPreference(
      Preference(
        category: PreferenceCategory.food,
        value: 'warm khichuri, not spicy',
        source: PreferenceSource.herAnswer,
        status: PreferenceStatus.confirmed,
        shared: true,
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
    );
    await db.insertPreference(
      Preference(
        category: PreferenceCategory.comfort,
        value: 'the grey blanket, kept warm',
        source: PreferenceSource.herAnswer,
        status: PreferenceStatus.confirmed,
        shared: true,
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
    );
    await db.insertPreference(
      Preference(
        category: PreferenceCategory.gesture,
        value: 'notes rather than phone calls',
        source: PreferenceSource.herAnswer,
        status: PreferenceStatus.confirmed,
        // Hidden on purpose: the screenshot shows that a private answer is
        // possible and is marked as such.
        shared: false,
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
    );
    await db.insertPreference(
      Preference(
        category: PreferenceCategory.dateIdea,
        value: 'a short walk after Maghrib',
        source: PreferenceSource.partnerObservation,
        status: PreferenceStatus.confirmed,
        shared: true,
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    );
    await db.insertPreference(
      Preference(
        category: PreferenceCategory.avoid,
        value: 'being asked to choose when she is tired',
        source: PreferenceSource.partnerObservation,
        status: PreferenceStatus.unconfirmed,
        shared: true,
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    );

    await db.upsertSymptom(
      Symptom(
        date: now.subtract(const Duration(days: 1)),
        kind: SymptomKind.fatigue,
        severity: 2,
        note: null,
        createdAt: now,
      ),
    );
  }

  /// Five recorded starts, roughly a 29 day rhythm.
  ///
  /// [daysSinceLastStart] moves the whole series so that today lands in a
  /// particular phase: the landing page changes its colour and its screenshot
  /// with the phase of the cycle, and those four images have to be renders of a
  /// history that actually puts the app in that phase — not four copies of one
  /// screen with a different caption.
  Future<void> seed({int daysSinceLastStart = 9}) async {
    final today = DateTime.now();
    // Offsets count backwards from today, so a *smaller* offset means the
    // period started more recently. Moving the series forward by the difference
    // is what lands today in the requested phase.
    final shift = daysSinceLastStart - 9;
    final offsets = [125, 97, 68, 39, 9].map((o) => o + shift).toList();
    for (final offset in offsets) {
      await db.insertCycle(
        CycleEntry(
          startDate: today.subtract(Duration(days: offset)),
          duration: 5,
        ),
      );
    }

    await seedPreferences();

    // Thirty days of cached climate so the heat-index chart has a series.
    for (var i = 29; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final heat = 33.0 + (i % 5) * 1.4;
      await db.upsertClimate(
        ClimateSnapshot(
          date: day,
          temperature: heat - 5.5,
          humidity: 78 + (i % 4),
          heatIndex: heat,
          sunshineHours: 4.5 + (i % 3) * 0.6,
          pm25: 38 + (i % 7) * 2,
          aqiCategory: 'Unhealthy for Sensitive Groups',
          fetchedAt: day,
        ),
      );
    }
  }

  /// Loads the providers over the seeded database.
  ///
  /// Everything here awaits real sqflite futures, so it must run inside
  /// [WidgetTester.runAsync]; under the test's fake clock those futures never
  /// complete and the test hangs.
  Future<_Graph> buildGraph(WidgetTester tester) async {
    late _Graph graph;
    await tester.runAsync(() async {
      final climateService = ClimateService(
        database: db,
        httpClient: _network(),
        timeout: const Duration(seconds: 1),
      );
      final consent = ConsentProvider(database: db);
      final settings = SettingsProvider(database: db);
      final cycles = CycleProvider(database: db);
      final climate = ClimateProvider(climateService: climateService);
      final prediction = PredictionProvider(
        predictionService: PredictionService(
          database: db,
          climateService: climateService,
        ),
      );
      final preferences = PreferencesProvider(database: db);
      final symptoms = SymptomsProvider(database: db);

      await consent.load();
      // A real user reaches these screens through the consent gate, so the
      // capture must show a recorded decision. Without this the Settings card
      // reads "Not recorded" while the app displays cycle data, which would be
      // both misleading in the README and a contradiction of the gate.
      if (consent.state != ConsentState.granted) {
        await consent.grant(method: ConsentMethod.setup);
      }
      await settings.load();
      await cycles.load();
      await prediction.refresh();
      await climate.load();
      await preferences.load();
      await symptoms.load();

      graph = _Graph(
        consent: consent,
        settings: settings,
        cycles: cycles,
        climate: climate,
        prediction: prediction,
        preferences: preferences,
        symptoms: symptoms,
      );
    });
    return graph;
  }

  Future<void> pumpApp(
    WidgetTester tester,
    _Graph graph, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          // Settings now renders the privacy card, which reads consent state
          // and offers export and deletion.
          ChangeNotifierProvider<ConsentProvider>.value(value: graph.consent),
          Provider<BackupService>(create: (_) => BackupService(database: db)),
          Provider<NotificationRescheduler>(create: (_) => _NoopRescheduler()),
          ChangeNotifierProvider<SettingsProvider>.value(value: graph.settings),
          ChangeNotifierProvider<CycleProvider>.value(value: graph.cycles),
          ChangeNotifierProvider<ClimateProvider>.value(value: graph.climate),
          ChangeNotifierProvider<PredictionProvider>.value(
            value: graph.prediction,
          ),
          ChangeNotifierProvider<PreferencesProvider>.value(
            value: graph.preferences,
          ),
          ChangeNotifierProvider<SymptomsProvider>.value(value: graph.symptoms),
          ChangeNotifierProvider<RemindersProvider>(
            create: (_) => RemindersProvider(database: db)..load(),
          ),
          ChangeNotifierProvider<RemindersProvider>(
            create: (_) => RemindersProvider(database: db)..load(),
          ),
          ChangeNotifierProvider<UpdateProvider>(
            create: (_) => UpdateProvider(),
          ),
        ],
        child: RepaintBoundary(
          key: _frameKey,
          // The theme follows the phase, exactly as main.dart builds it. A
          // capture that used the neutral theme drew a honey accent under a
          // rose hero panel, and the screenshots on the website then showed a
          // contradiction the app itself does not have.
          child: Builder(
            builder: (context) {
              final phaseKey = phaseKeyOfResult(
                context.watch<PredictionProvider>().result,
              );
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark
                    ? ElaraTheme.dark(phaseKey: phaseKey)
                    : ElaraTheme.light(phaseKey: phaseKey),
                home: const RootScaffold(),
              );
            },
          ),
        ),
      ),
    );

    await settle(tester);
  }

  /// Rasterises the framed app at 3x and writes it to docs/screenshots.
  ///
  /// Rendering directly, rather than through matchesGoldenFile, keeps the file
  /// write inside [WidgetTester.runAsync]: golden comparisons await real disk
  /// I/O, which cannot complete under the test's fake clock.
  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byKey(_frameKey),
    );

    // The one shadow in the design system should be visible in a screenshot.
    // Restored inside the test body, since the framework asserts that painting
    // debug flags are unchanged before teardown runs.
    debugDisableShadows = false;
    try {
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('docs/screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        // ignore: avoid_print
        print('wrote ${file.path} (${(await file.length()) ~/ 1024} KB)');
      });
    } finally {
      debugDisableShadows = true;
    }
  }

  /// Rasterises the framed app and writes it to an arbitrary path.
  ///
  /// Used by the font comparison, whose images do not belong in
  /// docs/screenshots/.
  Future<void> captureTo(WidgetTester tester, String path) async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byKey(_frameKey),
    );
    debugDisableShadows = false;
    try {
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        // ignore: avoid_print
        print('wrote ${file.path} (${(await file.length()) ~/ 1024} KB)');
      });
    } finally {
      debugDisableShadows = true;
    }
  }

  /// Sizes the fake window that Flutter lays out into.
  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  testWidgets('screenshots phone light', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    await capture(tester, 'today');

    await tester.tap(find.text('Calendar'));
    await settle(tester);
    await capture(tester, 'calendar');

    await tester.tap(find.text('Insights'));
    await settle(tester);
    await capture(tester, 'insights');

    await tester.tap(find.text('Settings'));
    await settle(tester);
    await capture(tester, 'settings');
  });

  /// The two states this app did not have before: a partner told the app that
  /// she is on hormonal contraception, and a pregnancy or loss that has stopped
  /// the counting. Both are rendered because both are screens someone will read
  /// in a hard week, and neither is an error state.
  /// One Today screen per phase.
  ///
  /// The website decides which of these to show from the date: on the tenth of
  /// the month it is ten days into a twenty-eight day cycle, so it shows the
  /// follicular one. That is a conceit, and the page says so — a website is not
  /// a person, and it has no cycle to be in.
  for (final (phase, daysAgo) in const [
    ('menstrual', 1),
    ('follicular', 8),
    ('ovulatory', 14),
    ('luteal', 21),
  ]) {
    testWidgets('screenshots the $phase phase', (tester) async {
      addTearDown(tester.view.reset);
      setViewport(tester, _logicalSize);

      await tester.runAsync(() => seed(daysSinceLastStart: daysAgo));
      final graph = await buildGraph(tester);
      await pumpApp(tester, graph);

      await capture(tester, 'today-$phase');
    });
  }

  testWidgets('screenshots quiet today', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);

    await tester.runAsync(
      () => graph.settings.setCycleMode(CycleMode.hormonalContraception),
    );
    await pumpApp(tester, graph);
    await capture(tester, 'today-hormonal-contraception');

    await tester.runAsync(
      () => graph.settings.setCycleMode(
        CycleMode.paused,
        reason: PauseReason.loss,
      ),
    );
    await pumpApp(tester, graph);
    await capture(tester, 'today-paused-after-loss');

    await tester.runAsync(
      () => graph.settings.setCycleMode(
        CycleMode.paused,
        reason: PauseReason.postpartum,
      ),
    );
    await pumpApp(tester, graph);
    await capture(tester, 'today-paused-after-birth');

    // And the setting itself, so the wording is reviewable in the same pass.
    await tester.runAsync(
      () => graph.settings.setCycleMode(CycleMode.predicting),
    );
    await pumpApp(tester, graph);
    await tester.tap(find.text('Settings'));
    // The screen transition is a fade and a rise, so one settle can land
    // mid-animation and capture a frame that is offset by a few pixels.
    await settle(tester);
    await tester.tap(find.text('Cycle mode'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    await capture(tester, 'settings-cycle-mode');
  });

  // The guidance section sits below the fold on a 390x844 phone. Scrolling the
  // real screen, rather than laying it out into an imaginary taller device and
  // cropping, keeps the capture an honest viewport: what is on show is what a
  // person sees after one flick.
  testWidgets('screenshots guidance light', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    // Far enough that the guidance section starts at the top of the frame, and
    // no further: -225 clips the section heading by four pixels, and dragging to
    // the end leaves dead space below the last line.
    await tester.dragFrom(const Offset(195, 500), const Offset(0, -215));
    await settle(tester);
    await capture(tester, 'today-action');
  });

  testWidgets('screenshots guidance dark', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph, dark: true);

    await tester.dragFrom(const Offset(195, 500), const Offset(0, -215));
    await settle(tester);
    await capture(tester, 'today-action-dark');
  });

  testWidgets('screenshots phone dark', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph, dark: true);
    await capture(tester, 'today-dark');

    await tester.tap(find.text('Calendar'));
    await settle(tester);
    await capture(tester, 'calendar-dark');

    // Settings in the dark palette, because the glass panels are the one
    // surface whose light and dark versions are not the same drawing: in light
    // the pane catches a highlight, in dark it is separated by its shadow. An
    // image is the only way to see whether that still reads.
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await capture(tester, 'settings-dark');
  });

  // A recorded day, opened the way a user opens it: back a month to the last
  // logged period start, then tap that date.
  testWidgets('screenshots day detail', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    await tester.tap(find.text('Calendar'));
    await settle(tester);
    await tester.tap(find.byTooltip('Previous month'));
    await settle(tester);
    await tester.tap(find.text('30'));
    await settle(tester);
    // The sheet is capped at 85% of the screen and scrolls, so it is dragged up
    // once to bring the action guidance into the same frame as the date.
    await tester.dragFrom(const Offset(195, 760), const Offset(0, -190));
    await settle(tester);
    await capture(tester, 'calendar-detail');
  });

  testWidgets('screenshots settings privacy', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    await tester.tap(find.text('Settings'));
    await settle(tester);
    // Privacy is its own page now, so the capture is of the subject rather than
    // of wherever a long scroll happened to stop.
    await tester.scrollUntilVisible(find.text('Privacy and data'), 200);
    await settle(tester);
    await tester.tap(find.text('Privacy and data'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    await capture(tester, 'settings-privacy');
  });

  // The About block lives at the foot of Settings: name, description, version
  // and build, and the medical-limitation line.
  testWidgets('screenshots about', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('About'), 200);
    await settle(tester);
    await tester.tap(find.text('About'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    // Dragged to the foot of the page: licence, engine, source link and the
    // medical-limitation line.
    await tester.dragFrom(const Offset(195, 500), const Offset(0, -180));
    await settle(tester);
    await capture(tester, 'about');
  });

  testWidgets('screenshots preferences', (tester) async {
    addTearDown(tester.view.reset);
    setViewport(tester, _logicalSize);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tester.tap(find.text('Preferences'));
    // A pushed route animates for 300 ms; without advancing past that the
    // capture catches the two screens cross-faded on top of each other.
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    await capture(tester, 'preferences');
  });

  testWidgets('screenshots tablet', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = _tabletSize;
    tester.view.devicePixelRatio = 1;

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    // The rail is the point of this shot: a wide window shows the navigation
    // rail beside a centred content column instead of a stretched phone layout.
    await capture(tester, 'tablet');
  });

  // The font comparison.
  //
  // The same screen, the same seeded data, rendered in each candidate
  // family. A specimen sheet of the letters is not evidence; the real screen,
  // with the real text at the real sizes, is.
  //
  //   flutter test tool/screenshots/screenshots_test.dart \
  //     --plain-name 'font comparison'
  //
  // The images land in tool/fonts/comparison/.
  // One test per candidate, so that the app is built fresh for each and
  // the navigation state cannot leak from one family into the next. A shared
  // test would have the second candidate start on whichever tab the first
  // one finished on.
  for (final candidate in _comparisonCandidates) {
    testWidgets('font comparison: ${candidate.id}', (tester) async {
      addTearDown(tester.view.reset);
      setViewport(tester, _logicalSize);

      ElaraTypography.overrideFamily(
        candidate.family,
        fallbacks: candidate.fallbacks,
      );
      addTearDown(ElaraTypography.resetFamily);

      await tester.runAsync(seed);
      final graph = await buildGraph(tester);
      await pumpApp(tester, graph);
      await captureTo(
        tester,
        'tool/fonts/comparison/${candidate.id}-today.png',
      );

      // The Bengali line on Today is the one place the two families differ
      // most: under DM Sans it is set in a different typeface, and the seam
      // is visible. The lunar strip is below the fold, so the screen is
      // scrolled to it first.
      // The lunar strip is the last item in a lazy list, so it is not in the
      // tree until the list is scrolled near it. A plain drag is enough; the
      // finder is checked afterwards.
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -260));
        await tester.pump(const Duration(milliseconds: 60));
        if (find
            .textContaining('\u0986', findRichText: true)
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await settle(tester);
      await captureTo(
        tester,
        'tool/fonts/comparison/${candidate.id}-bengali.png',
      );

      // The nav label, not the heading the Settings screen itself shows. The
      // label now lives in the app's own floating bar rather than a Material
      // NavigationDestination: the bar carries a raised centre action, which
      // NavigationBar has no way to express, so this taps the label inside it.
      await tester.tap(
        find.descendant(
          of: find.byType(ElaraNavBar),
          matching: find.text('Settings'),
        ),
      );
      await settle(tester);
      await captureTo(
        tester,
        'tool/fonts/comparison/${candidate.id}-settings.png',
      );
    });
  }
}

/// The families the font comparison renders the real screens in.
const List<({String id, String family, List<String> fallbacks})>
_comparisonCandidates = [
  (id: 'dmsans', family: 'DM Sans', fallbacks: ['Noto Sans Bengali']),
  (id: 'hind-siliguri', family: 'Hind Siliguri', fallbacks: <String>[]),
];

/// The provider graph the frame reads from.
class _Graph {
  _Graph({
    required this.consent,
    required this.settings,
    required this.cycles,
    required this.climate,
    required this.prediction,
    required this.preferences,
    required this.symptoms,
  });

  final ConsentProvider consent;
  final SettingsProvider settings;
  final CycleProvider cycles;
  final ClimateProvider climate;
  final PredictionProvider prediction;
  final PreferencesProvider preferences;
  final SymptomsProvider symptoms;
}

/// Stands in for the reminder layer so the screenshot run never touches a
/// platform channel.
class _NoopRescheduler implements NotificationRescheduler {
  @override
  Future<void> reschedule() async {}
}
