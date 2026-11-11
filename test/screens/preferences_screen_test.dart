import 'package:elara_app/data/database_helper.dart';
import 'package:elara_app/data/models/preference.dart';
import 'package:elara_app/providers/preferences_provider.dart';
import 'package:elara_app/screens/preferences/preferences_screen.dart';
import 'package:elara_app/theme/elara_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests for the preferences screen: the two perspectives, the share rule, and
/// the wording that admits the app cannot hide anything from the phone's owner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late PreferencesProvider prefs;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = DatabaseHelper.instance;
    db.overridePath = inMemoryDatabasePath;
    await db.close();
    prefs = PreferencesProvider(database: db);
  });

  tearDown(() async {
    await db.close();
    db.overridePath = null;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() => prefs.load());
    await tester.pumpWidget(
      ChangeNotifierProvider<PreferencesProvider>.value(
        value: prefs,
        child: MaterialApp(
          theme: ElaraTheme.light(),
          home: const PreferencesScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('starts empty, with both sections explained', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('What she has said'), findsOneWidget);
    expect(find.text('What you have noticed'), findsOneWidget);
    // The honest statement about same-device storage: the holder can read it.
    expect(
      find.textContaining('whoever holds the phone can open this screen'),
      findsOneWidget,
    );
  });

  testWidgets('a her-answer can be private, and private means unusable',
      (tester) async {
    await tester.runAsync(() => prefs.addHerAnswer(
          category: PreferenceCategory.food,
          value: 'khichuri',
          share: false,
        ));
    await pump(tester);

    expect(find.textContaining('Kept private'), findsOneWidget);
    expect(prefs.sharedAnswers, isEmpty);
    expect(prefs.herAnswers.single.canDriveSuggestions, isFalse);
  });

  testWidgets('a shared answer reaches the suggestion pool', (tester) async {
    await tester.runAsync(() => prefs.addHerAnswer(
          category: PreferenceCategory.food,
          value: 'khichuri',
          share: true,
        ));
    await pump(tester);

    expect(find.textContaining('Shared with you'), findsOneWidget);
    expect(prefs.sharedAnswers.single.value, 'khichuri');
  });

  testWidgets('an observation is stored as unconfirmed and says so',
      (tester) async {
    await tester.runAsync(() => prefs.addObservation(
          category: PreferenceCategory.comfort,
          value: 'the grey blanket',
        ));
    await pump(tester);

    expect(find.textContaining('Unconfirmed'), findsOneWidget);
    expect(
      find.textContaining('not as facts about her'),
      findsOneWidget,
    );

    // Confirming is a separate, explicit act.
    await tester.runAsync(() => prefs.confirm(prefs.observations.single));
    await tester.pump();
    expect(find.textContaining('Confirmed'), findsWidgets);
  });

  testWidgets('editing changes the value and persists it', (tester) async {
    await tester.runAsync(() => prefs.addObservation(
          category: PreferenceCategory.food,
          value: 'tea',
        ));
    await pump(tester);

    await tester.runAsync(() async {
      await prefs.update(prefs.observations.single.copyWith(value: 'ginger tea'));
    });
    await tester.pump();

    expect(find.text('ginger tea'), findsOneWidget);
    final reloaded = PreferencesProvider(database: db);
    await tester.runAsync(reloaded.load);
    expect(reloaded.observations.single.value, 'ginger tea');
  });

  testWidgets('deleting removes it from the list and the database',
      (tester) async {
    await tester.runAsync(() => prefs.addObservation(
          category: PreferenceCategory.gesture,
          value: 'a written note',
        ));
    await pump(tester);
    expect(find.text('a written note'), findsOneWidget);

    await tester.runAsync(() => prefs.delete(prefs.observations.single.id!));
    await tester.pump();

    expect(find.text('a written note'), findsNothing);
    expect(prefs.observations, isEmpty);
  });

  testWidgets('empty input is refused with a message, not a silent no-op',
      (tester) async {
    final ok = await tester.runAsync(
      () => prefs.addObservation(
        category: PreferenceCategory.food,
        value: '   ',
      ),
    );
    expect(ok, isFalse);
    expect(prefs.lastError, contains('Write something first'));
    expect(prefs.all, isEmpty);
  });

  testWidgets('an answer she wrote cannot be re-attributed to the holder',
      (tester) async {
    await tester.runAsync(() => prefs.addHerAnswer(
          category: PreferenceCategory.gesture,
          value: 'notes rather than texts',
          share: true,
        ));
    await pump(tester);

    final answer = prefs.herAnswers.single;
    expect(answer.isHerOwn, isTrue);
    // Editing keeps the source: the row stays in her section.
    await tester.runAsync(
      () => prefs.update(answer.copyWith(value: 'notes, never calls')),
    );
    await tester.pump();
    expect(prefs.herAnswers.single.value, 'notes, never calls');
    expect(prefs.observations, isEmpty);
  });
}
