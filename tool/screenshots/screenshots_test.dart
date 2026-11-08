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
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/screens/root_scaffold.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pixel 7 class logical size, rasterised at 3x for a 1170x2532 PNG.
const Size _logicalSize = Size(390, 844);
const double _pixelRatio = 3;

final GlobalKey _frameKey = GlobalKey();

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(File(path).readAsBytes().then((b) => ByteData.view(b.buffer)));
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
              '${day.day.toString().padLeft(2, '0')}'
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
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFont('Inter', [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
    ]);
    await _loadFont('Source Sans 3', [
      'assets/fonts/SourceSans3-Regular.ttf',
      'assets/fonts/SourceSans3-Medium.ttf',
      'assets/fonts/SourceSans3-SemiBold.ttf',
    ]);
    await _loadFont('SourceSans3', [
      'assets/fonts/SourceSans3-Regular.ttf',
      'assets/fonts/SourceSans3-Medium.ttf',
      'assets/fonts/SourceSans3-SemiBold.ttf',
    ]);
    // Icons come from the SDK, since a headless test has no system icon font.
    await _loadFont('MaterialIcons', [
      '/var/tmp/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
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

  /// Five recorded starts, roughly a 29 day rhythm, the newest nine days back.
  Future<void> seed() async {
    final today = DateTime.now();
    final offsets = [125, 97, 68, 39, 9];
    for (final offset in offsets) {
      await db.insertCycle(
        CycleEntry(
          startDate: today.subtract(Duration(days: offset)),
          duration: 5,
        ),
      );
    }

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
      final settings = SettingsProvider(database: db);
      final cycles = CycleProvider(database: db);
      final climate = ClimateProvider(climateService: climateService);
      final prediction = PredictionProvider(
        predictionService: PredictionService(
          database: db,
          climateService: climateService,
        ),
      );

      await settings.load();
      await cycles.load();
      await prediction.refresh();
      await climate.load();

      graph = _Graph(
        settings: settings,
        cycles: cycles,
        climate: climate,
        prediction: prediction,
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
          ChangeNotifierProvider<SettingsProvider>.value(value: graph.settings),
          ChangeNotifierProvider<CycleProvider>.value(value: graph.cycles),
          ChangeNotifierProvider<ClimateProvider>.value(value: graph.climate),
          ChangeNotifierProvider<PredictionProvider>.value(
              value: graph.prediction),
        ],
        child: RepaintBoundary(
          key: _frameKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? ElaraTheme.dark() : ElaraTheme.light(),
            home: const RootScaffold(),
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

  testWidgets('screenshots', (tester) async {
    tester.view.physicalSize = _logicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph);

    // Today.
    await capture(tester, 'today');

    // Calendar.
    await tester.tap(find.text('Calendar'));
    await settle(tester);
    await capture(tester, 'calendar');

    // Insights.
    await tester.tap(find.text('Insights'));
    await settle(tester);
    await capture(tester, 'insights');

    // Settings.
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await capture(tester, 'settings');
  });

  testWidgets('screenshots dark', (tester) async {
    tester.view.physicalSize = _logicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(seed);
    final graph = await buildGraph(tester);
    await pumpApp(tester, graph, dark: true);
    await capture(tester, 'today-dark');
  });
}

/// The provider graph the frame reads from.
class _Graph {
  _Graph({
    required this.settings,
    required this.cycles,
    required this.climate,
    required this.prediction,
  });

  final SettingsProvider settings;
  final CycleProvider cycles;
  final ClimateProvider climate;
  final PredictionProvider prediction;
}
