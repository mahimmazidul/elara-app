import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/settings_keys.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  group('SettingsProvider', () {
    test('loads the seeded defaults into typed getters', () async {
      final provider = SettingsProvider(database: db);
      await provider.load();

      expect(provider.isLoaded, isTrue);
      expect(provider.latitude, 23.8103);
      expect(provider.longitude, 90.4125);
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.themeModeKey, 'system');
      expect(provider.notificationsEnabled, isTrue);
      expect(provider.lastError, isNull);
    });

    test('persists a theme change and reports it', () async {
      final provider = SettingsProvider(database: db);
      await provider.load();
      final before = provider.revision;

      expect(await provider.setThemeMode(ThemeMode.dark), isTrue);
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.revision, greaterThan(before));

      // Written through to sqflite, not just held in memory.
      expect(await db.getSetting(SettingsKeys.themeMode), 'dark');
      final reloaded = SettingsProvider(database: db);
      await reloaded.load();
      expect(reloaded.themeMode, ThemeMode.dark);
    });

    test('persists the notification toggle', () async {
      final provider = SettingsProvider(database: db);
      await provider.load();

      await provider.setNotificationsEnabled(false);

      expect(provider.notificationsEnabled, isFalse);
      expect(await db.getSetting(SettingsKeys.notificationEnabled), 'false');
    });

    test('persists coordinates and rejects invalid ones', () async {
      final provider = SettingsProvider(database: db);
      await provider.load();

      expect(
        await provider.setLocation(latitude: 22.35, longitude: 91.78),
        isTrue,
      );
      expect(provider.latitude, 22.35);
      expect(await db.getSetting(SettingsKeys.latitude), '22.35');

      // Out of range: refused, and the stored value is untouched.
      expect(
        await provider.setLocation(latitude: 120, longitude: 0),
        isFalse,
      );
      expect(provider.lastError, isNotNull);
      expect(provider.latitude, 22.35);

      expect(
        await provider.setLocation(latitude: double.nan, longitude: 0),
        isFalse,
      );
    });

    test('rejects an empty settings key', () async {
      final provider = SettingsProvider(database: db);
      await provider.load();
      expect(await provider.setValue('  ', 'x'), isFalse);
      expect(provider.lastError, isNotNull);
    });

    test('notifies listeners on change', () async {
      final provider = SettingsProvider(database: db);
      await provider.load();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setThemeMode(ThemeMode.light);
      expect(notifications, greaterThan(0));
    });
  });

  group('CycleProvider', () {
    test('starts empty', () async {
      final provider = CycleProvider(database: db);
      await provider.load();

      expect(provider.isEmpty, isTrue);
      expect(provider.count, 0);
      expect(provider.latest, isNull);
      expect(provider.completedLengths, isEmpty);
    });

    test('adds a cycle and reloads from the database', () async {
      final provider = CycleProvider(database: db);
      await provider.load();

      final stored = await provider.addCycle(
        startDate: DateTime(2026, 1, 1),
        duration: 5,
      );

      expect(stored, isNotNull);
      expect(provider.count, 1);
      expect(provider.latest!.startDate, DateTime(2026, 1, 1));
      expect(provider.latest!.duration, 5);
      expect(await db.countCycles(), 1);
    });

    test('adding the same day twice updates rather than duplicating', () async {
      final provider = CycleProvider(database: db);
      await provider.load();

      await provider.addCycle(startDate: DateTime(2026, 1, 1), duration: 3);
      await provider.addCycle(startDate: DateTime(2026, 1, 1), duration: 6);

      expect(provider.count, 1);
      expect(provider.latest!.duration, 6);
    });

    test('refuses a future start date', () async {
      final provider = CycleProvider(database: db);
      await provider.load();

      final stored = await provider.addCycle(
        startDate: DateTime.now().add(const Duration(days: 3)),
      );

      expect(stored, isNull);
      expect(provider.lastError, contains('future'));
      expect(await db.countCycles(), 0);
    });

    test('refuses a duration below one day', () async {
      final provider = CycleProvider(database: db);
      await provider.load();

      final stored = await provider.addCycle(
        startDate: DateTime(2026, 1, 1),
        duration: 0,
      );

      expect(stored, isNull);
      expect(provider.lastError, isNotNull);
    });

    test('updates a duration and can clear it', () async {
      final provider = CycleProvider(database: db);
      await provider.load();
      final stored = await provider.addCycle(
        startDate: DateTime(2026, 1, 1),
        duration: 4,
      );

      expect(await provider.updateDuration(stored!.id!, 7), isTrue);
      expect(provider.latest!.duration, 7);

      expect(await provider.updateDuration(stored.id!, null), isTrue);
      expect(provider.latest!.duration, isNull);
    });

    test('deletes one cycle and clears all', () async {
      final provider = CycleProvider(database: db);
      await provider.load();
      final a = await provider.addCycle(startDate: DateTime(2026, 1, 1));
      await provider.addCycle(startDate: DateTime(2026, 2, 1));

      expect(await provider.deleteCycle(a!.id!), isTrue);
      expect(provider.count, 1);

      expect(await provider.deleteAll(), isTrue);
      expect(provider.isEmpty, isTrue);
    });

    test('computes completed cycle lengths', () async {
      final provider = CycleProvider(database: db);
      await provider.load();
      await provider.addCycle(startDate: DateTime(2026, 1, 1));
      await provider.addCycle(startDate: DateTime(2026, 1, 29));
      await provider.addCycle(startDate: DateTime(2026, 2, 26));

      expect(provider.completedLengths, [28, 28]);
    });

    test('bumps revision on mutation only', () async {
      final provider = CycleProvider(database: db);
      await provider.load();
      final initial = provider.revision;

      await provider.addCycle(startDate: DateTime(2026, 1, 1));
      expect(provider.revision, greaterThan(initial));

      final afterAdd = provider.revision;
      await provider.load();
      expect(provider.revision, afterAdd, reason: 'a reload is not a mutation');
    });
  });

  group('PredictionProvider', () {
    PredictionProvider build({DateTime? now}) {
      DateTime clock() => now ?? DateTime(2026, 4, 10, 9);
      return PredictionProvider(
        predictionService: PredictionService(
          database: db,
          climateService: ClimateService(
            database: db,
            httpClient: MockClient((_) async => http.Response('down', 500)),
            clock: clock,
            timeout: const Duration(seconds: 2),
          ),
          clock: clock,
        ),
      );
    }

    Future<void> seed({DateTime? now}) async {
      final anchor = now ?? DateTime(2026, 4, 10);
      for (var i = 3; i >= 0; i--) {
        await db.insertCycle(
          CycleEntry(
            startDate: anchor.subtract(Duration(days: 28 * i)),
            duration: 5,
          ),
        );
      }
    }

    test('refresh produces a result once history exists', () async {
      await seed();
      final provider = build();
      addTearDown(provider.dispose);

      expect(provider.hasResult, isFalse);

      final result = await provider.refresh();

      expect(result, isNotNull);
      expect(provider.hasResult, isTrue);
      expect(provider.lastUpdated, isNotNull);
      expect(provider.isLoading, isFalse);
      expect(provider.lastError, isNull);
    });

    test('reports no result and no error when history is empty', () async {
      final provider = build();
      addTearDown(provider.dispose);

      final result = await provider.refresh();

      expect(result, isNull);
      expect(provider.needsHistory, isTrue);
      expect(provider.lastError, isNull);
    });

    test('concurrent refreshes are collapsed into one run', () async {
      await seed();
      final provider = build();
      addTearDown(provider.dispose);

      final a = provider.refresh();
      final b = provider.refresh();
      final results = await Future.wait([a, b]);

      expect(identical(results[0], results[1]), isTrue);
    });

    // syncDependencies defers its work to a post-frame callback so it can be
    // called from a ProxyProvider update (i.e. during build). Driving real
    // sqflite I/O through a pumped frame would deadlock inside flutter_test's
    // fake-async zone, so this asserts the scheduling contract directly; the
    // end-to-end path is covered by the Provider refresh tests above.
    test('defers its refresh instead of running during build', () async {
      await seed();
      final provider = build();
      addTearDown(provider.dispose);

      // First sync schedules work (revisions start at -1) but must not start
      // it synchronously, which is what would break a build.
      await provider.syncDependencies(cycleRevision: 0, settingsRevision: 0);
      expect(provider.isLoading, isFalse);
      expect(provider.hasResult, isFalse);

      // Unchanged revisions schedule nothing at all.
      await provider.syncDependencies(cycleRevision: 0, settingsRevision: 0);
      expect(provider.isLoading, isFalse);
    });

    test('a foreground resume starts a refresh', () async {
      await seed();
      final provider = build();
      addTearDown(provider.dispose);

      expect(provider.isLoading, isFalse);
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // refresh() flips this synchronously before any I/O is awaited.
      expect(provider.isLoading, isTrue);

      // Let the in-flight run finish so the test does not leak it.
      await provider.refresh();
    });

    test('notifies listeners while loading', () async {
      await seed();
      final provider = build();
      addTearDown(provider.dispose);

      var notifications = 0;
      provider.addListener(() => notifications++);
      await provider.refresh();

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
