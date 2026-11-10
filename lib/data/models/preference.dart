/// What a preference is about.
///
/// The categories are shared by both perspectives. The app holder records
/// observations; she records her own answers. The same category means the same
/// thing in both, which is what lets a her-answer supersede an observation
/// rather than sit beside it contradicting it.
enum PreferenceCategory {
  /// Food and drink.
  food('Food and drink'),

  /// Activities and pastimes she enjoys.
  activity('Activities'),

  /// Things that help: a hot water bottle, a particular blanket.
  comfort('Comfort'),

  /// Gestures that land well.
  gesture('Gestures'),

  /// Things to avoid.
  avoid('Better avoided'),

  /// Kinds of date she enjoys.
  dateIdea('Dates'),

  /// Anything else, in the user's own words.
  note('Notes');

  const PreferenceCategory(this.label);

  /// Human-readable name, used in the picker and in summaries.
  final String label;

  static PreferenceCategory fromName(String name) => values.firstWhere(
        (value) => value.name == name,
        orElse: () => PreferenceCategory.note,
      );
}

/// Where a preference came from.
///
/// This is the single most important field in the table. An observation made by
/// the app holder is a guess about another person, however well informed; her
/// own answer is not. The UI has to keep them visually and textually distinct,
/// and the care engine prefers hers.
enum PreferenceSource {
  /// Recorded by the app holder from what they have noticed. Unverified.
  partnerObservation('You noticed this'),

  /// Written by her, in the questionnaire. Only she can confirm or edit it.
  herAnswer('She told you');

  const PreferenceSource(this.label);

  final String label;

  static PreferenceSource fromName(String name) => values.firstWhere(
        (value) => value.name == name,
        orElse: () => PreferenceSource.partnerObservation,
      );
}

/// Whether the information has been confirmed by the person it is about.
enum PreferenceStatus {
  /// Plausible, unverified. Shown as such and never stated as fact.
  unconfirmed('Unconfirmed'),

  /// She has confirmed it, either by writing it or by agreeing when asked.
  confirmed('Confirmed');

  const PreferenceStatus(this.label);

  final String label;

  static PreferenceStatus fromName(String name) => values.firstWhere(
        (value) => value.name == name,
        orElse: () => PreferenceStatus.unconfirmed,
      );
}

/// One row of `preferences`.
class Preference {
  const Preference({
    this.id,
    required this.category,
    required this.value,
    required this.source,
    required this.status,
    required this.shared,
    required this.updatedAt,
  });

  final int? id;
  final PreferenceCategory category;

  /// The preference itself, in the words of whoever wrote it.
  final String value;

  final PreferenceSource source;
  final PreferenceStatus status;

  /// Whether she chose to share this answer.
  ///
  /// Only meaningful for [PreferenceSource.herAnswer]: an observation is
  /// already visible to the person who made it. The questionnaire is honest
  /// that sharing here is not private storage — the app holder can read every
  /// row on the device — so this flag records a choice rather than enforcing a
  /// boundary.
  final bool shared;

  final DateTime updatedAt;

  /// True when this may be used to drive a care suggestion.
  bool get canDriveSuggestions =>
      source == PreferenceSource.herAnswer ? shared : true;

  /// Highest priority category first, for the care engine.
  bool get isHerOwn => source == PreferenceSource.herAnswer;

  factory Preference.fromMap(Map<String, Object?> map) {
    return Preference(
      id: map['id'] as int?,
      category: PreferenceCategory.fromName(map['category']! as String),
      value: map['value']! as String,
      source: PreferenceSource.fromName(map['source']! as String),
      status: PreferenceStatus.fromName(map['status']! as String),
      shared: (map['shared'] as num? ?? 0) != 0,
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  Map<String, Object?> toMap() => {
        'category': category.name,
        'value': value,
        'source': source.name,
        'status': status.name,
        'shared': shared ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
      };

  Preference copyWith({
    int? id,
    PreferenceCategory? category,
    String? value,
    PreferenceSource? source,
    PreferenceStatus? status,
    bool? shared,
    DateTime? updatedAt,
  }) {
    return Preference(
      id: id ?? this.id,
      category: category ?? this.category,
      value: value ?? this.value,
      source: source ?? this.source,
      status: status ?? this.status,
      shared: shared ?? this.shared,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Preference(${category.name}, ${source.name}, ${status.name}: $value)';
}
