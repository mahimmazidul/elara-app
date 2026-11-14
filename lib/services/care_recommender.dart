import '../data/generic_guidance.dart';
import '../data/models/climate_snapshot.dart';
import '../data/models/preference.dart';
import '../data/models/symptom.dart';

/// Where a suggestion came from, and therefore how much it can be trusted.
///
/// The ordering of this enum is the priority order the care engine uses, and it
/// is also what the UI shows under each suggestion. The distinction matters more
/// than the wording of any single suggestion: a partner needs to know whether
/// they are acting on something she said, something she reported today, or
/// something a calendar guessed.
enum CareBasis {
  /// She wrote it herself, in the questionnaire.
  herPreference('She told you this'),

  /// She reported it as a symptom in the last day or two.
  reportedSymptom('She reported this recently'),

  /// The app holder's own observation. Better than a guess, weaker than her word.
  yourObservation('From your notes'),

  /// Today's heat, air quality or season.
  environment('Because of today\u2019s weather'),

  /// The estimated cycle position.
  phase('From the estimated phase'),

  /// Nothing else applies: a standing, general idea.
  general('A general idea');

  const CareBasis(this.label);

  /// Short phrase naming the source, shown beneath the suggestion.
  final String label;

  /// True when the suggestion rests on something she said, rather than on an
  /// inference about her.
  bool get isKnown => this == CareBasis.herPreference ||
      this == CareBasis.reportedSymptom;

  /// True when the suggestion is an inference the user should treat cautiously.
  bool get isAssumption =>
      this == CareBasis.phase || this == CareBasis.environment;
}

/// What kind of thing is being suggested, used to pick an icon and to group.
enum CareKind {
  food,
  activity,
  comfort,
  gesture,
  ask,
  avoid,
  prepare,
  rest,
}

/// One suggestion, ready to render.
class CareSuggestion {
  const CareSuggestion({
    required this.title,
    required this.body,
    required this.basis,
    required this.kind,
    this.detail,
    this.source,
  });

  /// A short imperative: "Offer to make something she likes".
  final String title;

  /// One or two sentences of why and how.
  final String body;

  final CareBasis basis;
  final CareKind kind;

  /// Optional extra line, e.g. the food she actually mentioned.
  final String? detail;

  /// Where a general suggestion came from. Null for anything derived from her
  /// own data, because the source of that is her.
  final String? source;

  @override
  String toString() => 'CareSuggestion(${basis.name}: $title)';
}

/// Turns what the app knows into a small set of things worth doing today.
///
/// This replaces the phase-only advice the app used to give. The old version
/// read the cycle phase and returned the same three sentences it had returned in
/// that phase last month, which is both repetitive and faintly insulting: it
/// treats a person as a phase. The pipeline here is ordered by how much the
/// evidence actually tells you about *her*:
///
///   1. what she has said she likes (a direct statement)
///   2. what she reported feeling today (a current fact)
///   3. what the holder has written down (a good observation)
///   4. the weather (a shared, objective fact about the day)
///   5. a standing idea (no evidence, and labelled as such)
///
/// Phase-derived guidance is *not* produced here. It already exists in
/// elara-core's `ActionEngine`, whose wording is the app's phase voice, and it is
/// rendered by `ActionCards` immediately below this list. Keeping it in one place
/// avoids two blocks on the same screen saying the same thing in different
/// words.
///
/// Phase is deliberately below weather and well below anything she has said. It
/// is contextual information, and the suggestions built from it are phrased as
/// questions to ask rather than conclusions about how she feels. Nothing here
/// ever claims that a phase determines mood, affection, appetite or consent.
class CareRecommender {
  const CareRecommender();

  /// Suggestions to show on Today, strongest evidence first.
  ///
  /// [preferences] should be everything stored; entries she chose not to share
  /// are filtered here rather than at the call site, so no screen can leak them
  /// by forgetting the rule.
  List<CareSuggestion> recommend({
    required List<Preference> preferences,
    required List<Symptom> recentSymptoms,
    required ClimateSnapshot? climate,
    required DateTime today,
    int limit = 3,
  }) {
    final suggestions = <CareSuggestion>[];

    final usable = preferences.where((p) => p.canDriveSuggestions).toList()
      ..sort((a, b) {
        // Her own answers outrank observations; confirmed outranks unconfirmed;
        // otherwise the most recent wins.
        if (a.isHerOwn != b.isHerOwn) return a.isHerOwn ? -1 : 1;
        final aConfirmed = a.status == PreferenceStatus.confirmed;
        final bConfirmed = b.status == PreferenceStatus.confirmed;
        if (aConfirmed != bConfirmed) return aConfirmed ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final activeSymptoms = _activeSymptoms(recentSymptoms, today);

    // ---- 1. something she has actually said or confirmed
    final herPreference = usable.where((p) => p.isHerOwn).firstOrNull;
    if (herPreference != null) {
      suggestions.add(_fromPreference(herPreference, activeSymptoms));
    }

    // ---- 2. a reported symptom on a recent day
    if (activeSymptoms.isNotEmpty) {
      suggestions.add(_fromSymptom(activeSymptoms));
    }

    // ---- 3. the holder's own observation, if no her-answer covered it
    if (herPreference == null) {
      final observed = usable.where((p) => !p.isHerOwn).firstOrNull;
      if (observed != null) {
        suggestions.add(_fromPreference(observed, activeSymptoms));
      }
    }

    // ---- 4. the weather, which is a fact about the day rather than about her
    final environmental = _fromClimate(climate);
    if (environmental != null) suggestions.add(environmental);

    // ---- 5. a fallback that claims nothing
    if (suggestions.isEmpty) {
      suggestions.add(_fallback());
    }

    // De-duplicate by title, keeping the strongest basis.
    final seen = <String>{};
    final unique = <CareSuggestion>[];
    for (final suggestion in suggestions) {
      if (seen.add(suggestion.title)) unique.add(suggestion);
    }

    return unique.take(limit).toList();
  }

  /// General, source-backed advice for a phase, as suggestions.
  ///
  /// This is a separate call from [recommend] on purpose. What she has said and
  /// what she has reported are *about her* and belong first; general guidance is
  /// about the phase and belongs underneath, still shown when the personalised
  /// list is empty, and never mixed into the ranking where it could outrank
  /// something she actually told you.
  List<CareSuggestion> generalFor(
    String? phaseKey, {
    int limit = 2,
  }) {
    return GenericGuidanceTable.forPhase(phaseKey)
        .take(limit)
        .map(
          (item) => CareSuggestion(
            title: item.title,
            body: item.body,
            basis: CareBasis.general,
            kind: CareKind.prepare,
            // Most citations already name their publisher ("NICE CKS —
            // Ovulation pain"); repeating it as a prefix read as a stutter.
            source: item.citation.startsWith(item.source)
                ? item.citation
                : '${item.source} \u00b7 ${item.citation}',
          ),
        )
        .toList(growable: false);
  }

  /// Symptoms from the last two days.
  ///
  /// A two-day window because a symptom reported yesterday evening is still
  /// relevant this morning, while one from a fortnight ago is history.
  List<Symptom> _activeSymptoms(List<Symptom> symptoms, DateTime today) {
    final cutoff = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 2));
    final active = symptoms
        .where((s) => !s.date.isBefore(cutoff))
        .where((s) => !s.date.isAfter(today))
        .toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));
    return active;
  }

  CareSuggestion _fromPreference(
    Preference preference,
    List<Symptom> symptoms,
  ) {
    final asking = symptoms.isNotEmpty;

    switch (preference.category) {
      case PreferenceCategory.food:
        return CareSuggestion(
          title: asking
              ? 'Offer ${_lower(preference.value)} without being asked'
              : 'Something she likes: ${_lower(preference.value)}',
          body: asking
              ? 'She is having a hard day and this is something she has said '
                  'she likes. Making it available is a gesture; whether she '
                  'wants it now is still hers to decide.'
              : 'A concrete thing you can prepare or pick up. It costs little '
                  'and it shows you were paying attention.',
          basis: preference.isHerOwn
              ? CareBasis.herPreference
              : CareBasis.yourObservation,
          kind: CareKind.food,
        );

      case PreferenceCategory.comfort:
        return CareSuggestion(
          title: 'Have ${_lower(preference.value)} ready',
          body: 'Small practical comforts are easier to accept than offers of '
              'help. Put it where she will find it rather than presenting it.',
          basis: preference.isHerOwn
              ? CareBasis.herPreference
              : CareBasis.yourObservation,
          kind: CareKind.comfort,
        );

      case PreferenceCategory.gesture:
        return CareSuggestion(
          title: _sentenceCase(preference.value),
          body: 'A thoughtful gesture she has appreciated before and may '
              'welcome again today.',
          basis: preference.isHerOwn
              ? CareBasis.herPreference
              : CareBasis.yourObservation,
          kind: CareKind.gesture,
        );

      case PreferenceCategory.activity:
      case PreferenceCategory.dateIdea:
        return CareSuggestion(
          title: 'Plan something close to home',
          body: 'She enjoys ${_lower(preference.value)}. A short version that '
              'can be abandoned midway is safer than a big evening.',
          basis: preference.isHerOwn
              ? CareBasis.herPreference
              : CareBasis.yourObservation,
          kind: CareKind.activity,
        );

      case PreferenceCategory.avoid:
        return CareSuggestion(
          title: 'Give ${_lower(preference.value)} a miss today',
          body: 'She has asked for this to be left alone. Knowing what not to '
              'do is as useful as knowing what to offer.',
          basis: preference.isHerOwn
              ? CareBasis.herPreference
              : CareBasis.yourObservation,
          kind: CareKind.avoid,
        );

      case PreferenceCategory.note:
        return CareSuggestion(
          title: 'Worth remembering',
          body: preference.value,
          basis: preference.isHerOwn
              ? CareBasis.herPreference
              : CareBasis.yourObservation,
          kind: CareKind.ask,
        );
    }
  }

  CareSuggestion _fromSymptom(List<Symptom> symptoms) {
    final worst = symptoms.first;
    final name = worst.kind.label.toLowerCase();
    final severe = worst.severity >= 3;

    if (worst.kind == SymptomKind.bleeding) {
      return CareSuggestion(
        title: 'Put supplies where she will find them',
        body: 'She recorded bleeding today. Restocking without comment tends '
            'to land better than asking whether she needs anything.',
        basis: CareBasis.reportedSymptom,
        kind: CareKind.prepare,
        detail: '${worst.kind.label}: ${worst.severityLabel.toLowerCase()}',
      );
    }

    if (worst.kind == SymptomKind.moodChange) {
      return CareSuggestion(
        title: 'Take something off her plate',
        body: 'She noted feeling low or irritable. Doing a chore quietly '
            'removes a decision from her day without asking her to explain '
            'anything.',
        basis: CareBasis.reportedSymptom,
        kind: CareKind.gesture,
        detail: '${worst.kind.label}: ${worst.severityLabel.toLowerCase()}',
      );
    }

    if (worst.kind == SymptomKind.fatigue) {
      return CareSuggestion(
        title: 'Make rest the easy option',
        body: 'She reported fatigue. Cancel or postpone something rather than '
            'asking whether she wants to \u2014 the offer still leaves her the '
            'work of deciding.',
        basis: CareBasis.reportedSymptom,
        kind: CareKind.rest,
        detail: '${worst.kind.label}: ${worst.severityLabel.toLowerCase()}',
      );
    }

    return CareSuggestion(
      title: severe
          ? 'Ask what would actually help with the $name'
          : 'A quiet check-in about the $name',
      body: severe
          ? 'She reported this as severe. Ask directly and be ready to do '
              'nothing if that is the answer. Elara cannot tell what is wrong '
              'and is not a substitute for seeing someone about it.'
          : 'She mentioned it recently. A short question in passing is usually '
              'more welcome than a plan built around it.',
      basis: CareBasis.reportedSymptom,
      kind: CareKind.ask,
      detail: '${worst.kind.label}: ${worst.severityLabel.toLowerCase()}',
    );
  }

  CareSuggestion? _fromClimate(ClimateSnapshot? climate) {
    if (climate == null) return null;

    if (climate.heatIndex >= 38) {
      return CareSuggestion(
        title: 'Keep the day indoors and cool',
        body: 'The heat index is ${climate.heatIndex.toStringAsFixed(0)}\u00b0C. '
            'Suggesting something at home is practical rather than cautious, '
            'and it saves her from having to say no to going out.',
        basis: CareBasis.environment,
        kind: CareKind.activity,
      );
    }

    if (climate.pm25 >= 100) {
      return CareSuggestion(
        title: 'Close the windows and stay in',
        body: 'Air quality is poor today at ${climate.pm25.toStringAsFixed(0)} '
            '\u00b5g/m\u00b3. A reason to keep plans indoors that has nothing to '
            'do with her.',
        basis: CareBasis.environment,
        kind: CareKind.activity,
      );
    }

    if (climate.heatIndex >= 33) {
      return CareSuggestion(
        title: 'Have cold water and something light ready',
        body: 'It is warm enough to be draining. Small preparations are more '
            'useful than asking whether she is too hot.',
        basis: CareBasis.environment,
        kind: CareKind.comfort,
      );
    }

    return null;
  }

  CareSuggestion _fallback() {
    return const CareSuggestion(
      title: 'Ask one specific question',
      body: 'Elara has nothing recorded about what she finds helpful. A '
          'question like "what would make this evening easier" tells you more '
          'than any suggestion here, and you can add the answer to her '
          'preferences so tomorrow is better.',
      basis: CareBasis.general,
      kind: CareKind.ask,
    );
  }

  static String _lower(String value) {
    if (value.isEmpty) return value;
    final first = value.substring(0, 1);
    // Leave proper nouns and non-Latin scripts alone.
    if (first != first.toLowerCase()) {
      final rest = value.substring(1);
      final looksLikeProperNoun = rest.isNotEmpty && rest[0] == rest[0].toUpperCase();
      if (looksLikeProperNoun) return value;
    }
    return value[0].toLowerCase() + value.substring(1);
  }

  static String _sentenceCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
