import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/cycle_entry.dart';
import 'package:elara_app/providers/climate_provider.dart';
import 'package:elara_app/providers/cycle_provider.dart';
import 'package:elara_app/providers/prediction_provider.dart';
import 'package:elara_app/providers/reminders_provider.dart';
import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/providers/settings_provider.dart';
import 'package:elara_app/providers/symptoms_provider.dart';
import 'package:elara_app/screens/calendar/calendar_screen.dart';
import 'package:elara_app/services/climate_service.dart';
import 'package:elara_app/services/prediction_service.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// What a screen reader is told about the calendar.
///
/// The grid conveys its meaning entirely through colour and a dot, so the
/// semantics label is the only accessible version of that information. These
/// tests assert the label exists and actually says which phase, whether the day
/// was recorded, and whether it is a projection.
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

  testWidgets('calendar days announce date, phase and provenance',
      (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 5));

    await tester.runAsync(() async {
      await db.insertCycle(
        CycleEntry(startDate: start.subtract(const Duration(days: 28)),
            duration: 5),
      );
      await db.insertCycle(CycleEntry(startDate: start, duration: 5));
    });

    late CycleProvider cycles;
    late PredictionProvider prediction;
    late SettingsProvider settings;
    late ClimateProvider climate;
    late SymptomsProvider symptoms;
    late RemindersProvider reminders;

    await tester.runAsync(() async {
      final service = ClimateService(
        database: db,
        httpClient: MockClient((_) async => http.Response('offline', 503)),
        timeout: const Duration(seconds: 1),
      );
      cycles = CycleProvider(database: db);
      settings = SettingsProvider(database: db);
      climate = ClimateProvider(climateService: service);
      prediction = PredictionProvider(
        predictionService: PredictionService(
          database: db,
          climateService: service,
        ),
      );
      symptoms = SymptomsProvider(database: db);
      reminders = RemindersProvider(database: db);
      await settings.load();
      await cycles.load();
      await symptoms.load();
      await reminders.load();
      await prediction.refresh();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          ChangeNotifierProvider<CycleProvider>.value(value: cycles),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ClimateProvider>.value(value: climate),
          ChangeNotifierProvider<PredictionProvider>.value(value: prediction),
          ChangeNotifierProvider<SymptomsProvider>.value(value: symptoms),
          ChangeNotifierProvider<RemindersProvider>.value(value: reminders),
          ChangeNotifierProvider<UpdateProvider>(
            create: (_) => UpdateProvider(),
          ),
        ],
        child: MaterialApp(
          theme: ElaraTheme.light(),
          home: const Scaffold(body: CalendarScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    // Collect every day cell's semantics label.
    final labels = <String>[];
    for (final element in find.byType(Semantics).evaluate()) {
      final widget = element.widget as Semantics;
      final label = widget.properties.label;
      if (label != null && label.contains(',')) labels.add(label);
    }

    expect(labels, isNotEmpty, reason: 'day cells must carry a label');
    expect(
      labels.any((l) => l.contains('recorded')),
      isTrue,
      reason: 'a recorded day must say so',
    );
    expect(
      labels.any((l) => l.contains('projected')),
      isTrue,
      reason: 'a projected day must say so',
    );
    expect(
      labels.any((l) => l.contains('not a confirmed phase')),
      isTrue,
      reason: 'a projection must never sound like a measurement',
    );
    // Every label opens with a date, never a bare number.
    for (final label in labels) {
      expect(label, matches(RegExp(r'^\d{1,2} \w{3}')));
    }
  });
}
