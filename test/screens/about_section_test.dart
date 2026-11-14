import 'dart:convert';

import 'package:elara_app/app_info.dart';
import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/screens/settings/about_section.dart';
import 'package:elara_app/services/update_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The About card and the update row: what it claims, and what it refuses to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late SettingsProvider settings;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance;
    db.overridePath = inMemoryDatabasePath;
    await db.close();
    settings = SettingsProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  /// A phone with no connection: the request itself fails, which is the only
  /// thing that may be described to the user as offline.
  http.Client offline() => MockClient(
    (_) async => throw http.ClientException('Network unreachable'),
  );

  /// GitHub answering with a server error, which is a different sentence: the
  /// phone has a connection, the service on the other end does not work.
  http.Client serverError() => MockClient((_) async => http.Response('', 503));

  http.Client release(String tag) => MockClient(
    (_) async => http.Response(
      jsonEncode({
        'tag_name': tag,
        'name': 'Elara $tag',
        'body': 'Fixes for irregular cycles.',
        'html_url': 'https://github.com/mahimmazidul/elara-app/releases',
        'prerelease': false,
        'published_at': '2026-11-01T00:00:00Z',
        'assets': [
          {
            'name': 'elara-arm64-v8a.apk',
            'browser_download_url':
                'https://github.com/mahimmazidul/elara-app/releases/download/v/elara-arm64-v8a.apk',
            'size': 22000000,
          },
        ],
      }),
      200,
    ),
  );

  Future<UpdateProvider> pump(
    WidgetTester tester, {
    http.Client? client,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    final updates = UpdateProvider(
      service: UpdateService(httpClient: client ?? offline()),
      installedVersion: AppInfo.version,
    );
    await tester.runAsync(() => settings.load());
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
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<UpdateProvider>.value(value: updates),
          ],
          child: MaterialApp(
            theme: ElaraTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(ElaraSpacing.lg),
                  child: AboutSection(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return updates;
  }

  testWidgets('shows the installed version and build from app metadata', (
    tester,
  ) async {
    await pump(tester);

    final plus = AppInfo.version.indexOf('+');
    final version = AppInfo.version.substring(0, plus);
    final build = AppInfo.version.substring(plus + 1);

    expect(find.text('$version (build $build)'), findsOneWidget);
    expect(find.text(AppInfo.license), findsOneWidget);
    expect(find.text('Md. Mazidul Islam Mahim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers the author the reader can actually reach', (tester) async {
    await pump(tester);

    // The panel used to say "Elara publishes no social accounts", which was a
    // denial in the place a link belongs, and by the time it was noticed it was
    // also untrue. The rows now name the accounts the author keeps, and the URL
    // is in AppInfo so it is written once.
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);

    // Still never a raw URL on screen, and still nothing invented: an account
    // the author does not have would be worse than none.
    expect(find.textContaining('facebook.com'), findsNothing);
    expect(find.textContaining('t.me'), findsNothing);
    expect(find.textContaining('twitter.com'), findsNothing);
    expect(find.textContaining('instagram.com'), findsNothing);
  });

  testWidgets('the prediction engine is named, not linked', (tester) async {
    await pump(tester);

    // The engine is a dependency, and its repository is not something a reader
    // of this panel can act on. It is stated as a fact beside the licence.
    expect(find.text('elara-core'), findsOneWidget);
    expect(find.text('Prediction engine'), findsOneWidget);
    expect(
      find.text(
        'Elara’s own ensemble, developed from OpenCiclo and Flowlytics.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining(r'\u2019'), findsNothing);
  });

  testWidgets('the limitations panel carries the medical and privacy claims', (
    tester,
  ) async {
    await pump(tester);

    // The heading is a sentence, not a fragment: the fragment began with a
    // lowercase letter and read as truncated text rather than as a statement.
    expect(find.text('An estimate, and how far to trust it'), findsOneWidget);
    // Where the data lives, said positively: the panel used to list the things
    // the app does not have, which is an argument with nobody.
    expect(find.textContaining('stays on this phone'), findsOneWidget);
    expect(
      find.textContaining('reads the dates you record and estimates'),
      findsOneWidget,
    );
  });

  testWidgets('link rows name the destination and print no URL', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Source code'), findsOneWidget);
    // A URL is not a label: it truncates on a phone and tells the reader
    // nothing the word above it did not.
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.textContaining('http'), findsNothing);
  });

  testWidgets('an unchecked row says so and does not imply current', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Not checked yet'), findsOneWidget);
  });

  testWidgets('a newer release opens a sheet with notes and file sizes', (
    tester,
  ) async {
    await pump(tester, client: release('v9.9.9'));

    await tester.runAsync(() async {
      await tester.scrollUntilVisible(find.text('Check for updates'), 200);
      await tester.tap(find.text('Check for updates'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Version 9.9.9 is available'), findsOneWidget);
    expect(find.text('Fixes for irregular cycles.'), findsOneWidget);
    expect(find.textContaining('elara-arm64-v8a.apk'), findsOneWidget);
    expect(find.textContaining('21.0 MB'), findsOneWidget);
    // It offers a link and says it will not install anything itself.
    expect(
      find.textContaining('will not install this for you'),
      findsOneWidget,
    );
  });

  testWidgets('an offline check explains itself and does not claim current', (
    tester,
  ) async {
    await pump(tester);

    await tester.runAsync(() async {
      await tester.scrollUntilVisible(find.text('Check for updates'), 200);
      await tester.tap(find.text('Check for updates'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Could not check for updates'), findsOneWidget);
    expect(find.textContaining('works offline'), findsOneWidget);
  });

  testWidgets('a server error is not called offline, and claims nothing', (
    tester,
  ) async {
    await pump(tester, client: serverError());

    await tester.runAsync(() async {
      await tester.scrollUntilVisible(find.text('Check for updates'), 200);
      await tester.tap(find.text('Check for updates'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Once in the Settings row, once as the sheet title.
    expect(find.text('Check failed'), findsWidgets);
    // The exact status, because it is the only actionable part.
    expect(find.textContaining('status 503'), findsOneWidget);
    // And it does not tell a connected phone that it has no connection.
    expect(find.text('Could not check for updates'), findsNothing);
    expect(find.textContaining('You already have the latest'), findsNothing);
  });

  testWidgets('automatic checking is off by default and can be switched on', (
    tester,
  ) async {
    await pump(tester);

    expect(settings.updatesAutoCheck, isFalse);
    expect(find.text('Check on start-up'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.scrollUntilVisible(find.text('Check on start-up'), 200);
      await tester.tap(find.text('Check on start-up'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();

    expect(settings.updatesAutoCheck, isTrue);
  });

  for (final width in <double>[320, 360, 390, 430]) {
    for (final scale in <double>[1.0, 1.5, 2.0]) {
      testWidgets('lays out at ${width.toInt()}dp and ${scale}x text', (
        tester,
      ) async {
        await pump(tester, size: Size(width, 900), textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
