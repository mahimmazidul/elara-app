import 'package:elara_app/data/models/climate_snapshot.dart';
import 'package:elara_app/data/models/preference.dart';
import 'package:elara_app/data/models/symptom.dart';
import 'package:elara_app/services/care_recommender.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the care pipeline, which decides what Today suggests.
///
/// Two things are being protected here. The first is priority: something she said
/// must outrank something the app inferred, and the weather must outrank the
/// phase. The second is honesty: every suggestion must carry a basis that says
/// whether it is known information or an assumption, because a partner acting on
/// an assumption believing it is a fact is the failure mode this app exists to
/// avoid.
void main() {
  const recommender = CareRecommender();
  final today = DateTime(2026, 11, 8);

  Preference preference({
    PreferenceCategory category = PreferenceCategory.food,
    PreferenceSource source = PreferenceSource.herAnswer,
    PreferenceStatus status = PreferenceStatus.confirmed,
    bool shared = true,
    String value = 'khichuri',
    int daysAgo = 0,
  }) =>
      Preference(
        category: category,
        value: value,
        source: source,
        status: status,
        shared: shared,
        updatedAt: today.subtract(Duration(days: daysAgo)),
      );

  Symptom symptom({
    SymptomKind kind = SymptomKind.cramps,
    int severity = 2,
    int daysAgo = 0,
  }) =>
      Symptom(
        date: today.subtract(Duration(days: daysAgo)),
        kind: kind,
        severity: severity,
        createdAt: today,
      );

  ClimateSnapshot climate({double heatIndex = 30, double pm25 = 40}) =>
      ClimateSnapshot(
        date: today,
        temperature: heatIndex - 3,
        humidity: 70,
        heatIndex: heatIndex,
        sunshineHours: 6,
        pm25: pm25,
        aqiCategory: 'moderate',
      );

  List<CareSuggestion> run({
    List<Preference> preferences = const [],
    List<Symptom> symptoms = const [],
    ClimateSnapshot? environment,
  }) =>
      recommender.recommend(
        preferences: preferences,
        recentSymptoms: symptoms,
        climate: environment,
        today: today,
      );

  group('generation', () {
    test('always returns at least one suggestion', () {
      expect(run(), isNotEmpty);
    });

    test('falls back to a general idea when nothing is known', () {
      final result = run();
      expect(result.single.basis, CareBasis.general);
      expect(result.single.basis.isKnown, isFalse);
      expect(result.single.kind, CareKind.ask);
    });

    test('produces a suggestion for every preference category', () {
      for (final category in PreferenceCategory.values) {
        final result = run(preferences: [preference(category: category)]);
        expect(
          result,
          isNotEmpty,
          reason: 'no suggestion generated for ${category.name}',
        );
        // The value she or the holder wrote must reach the copy: a suggestion
        // that ignores the stored value is not using the preference at all.
        if (category != PreferenceCategory.note) {
          expect(
            '${result.first.title} ${result.first.body}'.toLowerCase(),
            contains('khichuri'),
            reason: 'value missing for ${category.name}',
          );
        }
      }
    });

    test('symptom-only input yields a reported-symptom suggestion', () {
      final result = run(symptoms: [symptom(kind: SymptomKind.fatigue)]);
      expect(result.first.basis, CareBasis.reportedSymptom);
      expect(result.first.basis.isKnown, isTrue);
    });

    test('bleeding produces a supplies suggestion, not a diagnosis', () {
      final result = run(symptoms: [symptom(kind: SymptomKind.bleeding)]);
      expect(result.first.kind, CareKind.prepare);
      // Nothing in the copy may name a condition.
      for (final suggestion in result) {
        final text = '${suggestion.title} ${suggestion.body}'.toLowerCase();
        for (final condition in ['pcos', 'pmdd', 'endometriosis', 'infection']) {
          expect(text, isNot(contains(condition)));
        }
      }
    });
  });

  group('priority', () {
    test('her own answer outranks an observation', () {
      final result = run(preferences: [
        preference(
          value: 'mishti doi',
          source: PreferenceSource.partnerObservation,
          status: PreferenceStatus.unconfirmed,
          daysAgo: 1,
        ),
        preference(
          value: 'khichuri',
          source: PreferenceSource.herAnswer,
          daysAgo: 9,
        ),
      ]);
      expect(result.first.basis, CareBasis.herPreference);
      expect(
        '${result.first.title} ${result.first.body}'.toLowerCase(),
        contains('khichuri'),
      );
    });

    test('a confirmed observation outranks an older unconfirmed one', () {
      final result = run(preferences: [
        preference(
          value: 'old idea',
          source: PreferenceSource.partnerObservation,
          status: PreferenceStatus.unconfirmed,
          daysAgo: 30,
        ),
        preference(
          value: 'confirmed idea',
          source: PreferenceSource.partnerObservation,
          status: PreferenceStatus.confirmed,
          daysAgo: 20,
        ),
      ]);
      expect(
        '${result.first.title} ${result.first.body}'.toLowerCase(),
        contains('confirmed idea'),
      );
    });

    test('a shared answer outranks a reported symptom', () {
      final result = run(
        preferences: [preference()],
        symptoms: [symptom()],
      );
      expect(result.first.basis, CareBasis.herPreference);
      expect(result.any((s) => s.basis == CareBasis.reportedSymptom), isTrue);
    });

    test('environment outranks nothing known and is labelled as an assumption',
        () {
      final result = run(environment: climate(heatIndex: 41));
      expect(result.first.basis, CareBasis.environment);
      expect(result.first.basis.isAssumption, isTrue);
      expect(result.first.basis.isKnown, isFalse);
    });

    test('extreme heat suggests staying indoors, which is climate-aware', () {
      final result = run(environment: climate(heatIndex: 41));
      expect(result.first.title.toLowerCase(), contains('indoors'));
    });

    test('poor air quality is handled too', () {
      final result = run(environment: climate(heatIndex: 30, pm25: 160));
      expect(result.first.kind, CareKind.activity);
      expect(result.first.body.toLowerCase(), contains('air quality'));
    });
  });

  group('consent', () {
    test('an answer she chose not to share never drives a suggestion', () {
      final result = run(preferences: [
        preference(value: 'private thing', source: PreferenceSource.herAnswer,
            shared: false),
      ]);
      for (final suggestion in result) {
        expect(suggestion.basis, isNot(CareBasis.herPreference));
        expect(suggestion.body.toLowerCase(), isNot(contains('private thing')));
      }
    });

    test('an unconfirmed observation is still usable but labelled as one', () {
      final result = run(preferences: [
        preference(source: PreferenceSource.partnerObservation,
            status: PreferenceStatus.unconfirmed),
      ]);
      expect(result.first.basis, CareBasis.yourObservation);
      expect(result.first.basis.isKnown, isFalse);
      expect(result.first.basis.isAssumption, isFalse);
    });
  });

  group('limits and hygiene', () {
    test('respects the limit', () {
      final result = recommender.recommend(
        preferences: [
          preference(value: 'khichuri'),
          preference(category: PreferenceCategory.comfort, value: 'a hot bag'),
          preference(category: PreferenceCategory.gesture, value: 'a note'),
        ],
        recentSymptoms: [symptom()],
        climate: climate(heatIndex: 41),
        today: today,
        limit: 2,
      );
      expect(result.length, 2);
    });

    test('old symptoms drop out of the active window', () {
      final result = run(symptoms: [symptom(daysAgo: 30, severity: 3)]);
      expect(result.any((s) => s.basis == CareBasis.reportedSymptom), isFalse);
    });

    test('no suggestion claims that a phase determines feelings', () {
      final result = run(
        preferences: [preference()],
        symptoms: [symptom()],
        environment: climate(heatIndex: 41),
      );
      for (final suggestion in result) {
        final text = '${suggestion.title} ${suggestion.body}'.toLowerCase();
        expect(text, isNot(contains('in the mood')));
        expect(text, isNot(contains('she will want')));
        expect(text, isNot(contains('guaranteed')));
      }
    });

    test('titles are de-duplicated', () {
      final result = run(preferences: [
        preference(value: 'khichuri'),
        preference(value: 'khichuri'),
      ]);
      final titles = result.map((s) => s.title).toList();
      expect(titles.length, titles.toSet().length);
    });
  });
}
