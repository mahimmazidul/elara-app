import '../date_keys.dart';

/// A symptom that can be logged, from the partner's own report.
enum SymptomKind {
  cramps('Cramps'),
  headache('Headache'),
  fatigue('Fatigue'),
  bloating('Bloating'),
  nausea('Nausea'),
  breastTenderness('Breast tenderness'),
  moodChange('Low mood or irritability'),
  bleeding('Bleeding');

  const SymptomKind(this.label);

  final String label;

  /// Bleeding is recorded as a flow rather than a severity, so the UI labels its
  /// scale differently.
  bool get isFlow => this == SymptomKind.bleeding;

  /// The low and high ends of the three-point scale.
  String get scaleLow => isFlow ? 'Light' : 'Mild';
  String get scaleHigh => isFlow ? 'Heavy' : 'Severe';
  String get scaleMid => isFlow ? 'Moderate' : 'Moderate';

  static SymptomKind fromName(String name) => values.firstWhere(
        (value) => value.name == name,
        orElse: () => SymptomKind.cramps,
      );
}

/// One row of `symptoms`: something she reported on a particular day.
///
/// Deliberately not a diagnosis and not a score. A symptom only ever does one
/// thing in this app: it lets a care suggestion skip or soften itself, because a
/// reported headache is better evidence than an estimated phase.
class Symptom {
  const Symptom({
    this.id,
    required this.date,
    required this.kind,
    required this.severity,
    this.note,
    required this.createdAt,
  });

  final int? id;

  /// The calendar day, at local midnight.
  final DateTime date;

  final SymptomKind kind;

  /// 1 to 3: mild/moderate/severe, or light/moderate/heavy for bleeding.
  final int severity;

  final String? note;
  final DateTime createdAt;

  String get severityLabel {
    switch (severity) {
      case 1:
        return kind.scaleLow;
      case 3:
        return kind.scaleHigh;
      default:
        return kind.scaleMid;
    }
  }

  factory Symptom.fromMap(Map<String, Object?> map) {
    return Symptom(
      id: map['id'] as int?,
      // Dates are stored as yyyy-MM-dd (see date_keys.dart). parseDateKey also
      // accepts a full ISO string, so a row written by an earlier build still
      // reads correctly.
      date: parseDateKey(map['date']! as String),
      kind: SymptomKind.fromName(map['kind']! as String),
      severity: (map['severity'] as num?)?.toInt() ?? 2,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() => {
        // A calendar date, not an instant: yyyy-MM-dd, matching the queries.
        'date': dateKey(date),
        'kind': kind.name,
        'severity': severity,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  Symptom copyWith({
    int? id,
    DateTime? date,
    SymptomKind? kind,
    int? severity,
    String? note,
    bool clearNote = false,
  }) {
    return Symptom(
      id: id ?? this.id,
      date: date ?? this.date,
      kind: kind ?? this.kind,
      severity: severity ?? this.severity,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'Symptom(${kind.name} sev$severity on $date)';
}
