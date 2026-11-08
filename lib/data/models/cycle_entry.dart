import '../date_keys.dart';

/// One recorded period, as stored in the `cycles` table.
///
/// [startDate] is a calendar date (local midnight). [duration] is the bleeding
/// length in days when the user supplied one; `null` means "not recorded",
/// which the prediction engine treats differently from a known short period.
class CycleEntry {
  CycleEntry({
    this.id,
    required DateTime startDate,
    this.duration,
    DateTime? createdAt,
  })  : startDate = dateOnly(startDate),
        createdAt = createdAt ?? DateTime.now() {
    if (duration != null && duration! < 1) {
      throw ArgumentError.value(duration, 'duration', 'must be at least 1 day');
    }
  }

  final int? id;
  final DateTime startDate;
  final int? duration;
  final DateTime createdAt;

  /// True when this row has been persisted and carries a database id.
  bool get isPersisted => id != null;

  factory CycleEntry.fromMap(Map<String, Object?> map) {
    final rawDuration = map['duration'];
    return CycleEntry(
      id: map['id'] as int?,
      startDate: parseDateKey(map['start_date']! as String),
      duration: rawDuration == null ? null : (rawDuration as num).toInt(),
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  /// Column map for insert/update. [includeId] is false for inserts so SQLite
  /// assigns the autoincrement id.
  Map<String, Object?> toMap({bool includeId = false}) => {
        if (includeId && id != null) 'id': id,
        'start_date': dateKey(startDate),
        'duration': duration,
        'created_at': timestampKey(createdAt),
      };

  CycleEntry copyWith({
    int? id,
    DateTime? startDate,
    int? duration,
    bool clearDuration = false,
    DateTime? createdAt,
  }) {
    return CycleEntry(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      duration: clearDuration ? null : (duration ?? this.duration),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'CycleEntry(id: $id, start: ${dateKey(startDate)}, duration: $duration)';

  @override
  bool operator ==(Object other) =>
      other is CycleEntry &&
      other.id == id &&
      other.startDate == startDate &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(id, startDate, duration);
}
