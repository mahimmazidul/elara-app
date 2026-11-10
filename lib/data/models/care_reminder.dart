import '../date_keys.dart';

/// One thing to remember on one day.
///
/// This is the practical half of planning: "bring the hot water bottle",
/// "the scan is at 4", "buy the chocolate she likes before Thursday". It is a
/// note attached to a date, not a task manager, and it carries no score and no
/// claim about anyone's feelings.
class CareReminder {
  const CareReminder({
    this.id,
    required this.date,
    required this.title,
    this.note,
    this.done = false,
    required this.createdAt,
  });

  final int? id;

  /// The day it belongs to, at local midnight.
  final DateTime date;

  /// The line itself. Kept short enough to read on a calendar cell tooltip.
  final String title;

  /// Optional detail: where, when, or why.
  final String? note;

  /// Ticked off. A done reminder stays visible on its day rather than vanishing,
  /// because "I already did that" is worth being able to see.
  final bool done;

  final DateTime createdAt;

  factory CareReminder.fromMap(Map<String, Object?> map) {
    return CareReminder(
      id: map['id'] as int?,
      date: parseDateKey(map['date']! as String),
      title: map['title']! as String,
      note: map['note'] as String?,
      done: (map['done'] as num?)?.toInt() == 1,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  Map<String, Object?> toMap() => {
        // yyyy-MM-dd, like every other calendar date in the database.
        'date': dateKey(date),
        'title': title,
        'note': note,
        'done': done ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  CareReminder copyWith({
    int? id,
    DateTime? date,
    String? title,
    String? note,
    bool? done,
    bool clearNote = false,
  }) {
    return CareReminder(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      done: done ?? this.done,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'CareReminder($title on $date, done: $done)';
}
