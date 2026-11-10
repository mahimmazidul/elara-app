import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../data/date_keys.dart';
import '../data/models/symptom.dart';

/// Owns the `symptoms` table.
///
/// Symptoms are entirely optional and are never solicited by the app: there is
/// no prompt asking her to log anything, and no streak to maintain. A day with
/// no records is a normal day, not a gap.
class SymptomsProvider extends ChangeNotifier {
  SymptomsProvider({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  List<Symptom> _recent = const [];
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _lastError;
  int _revision = 0;

  /// How far back the in-memory window reaches. Two months covers the care
  /// engine's needs and the calendar's month view without loading a year.
  static const int windowDays = 60;

  /// Recent symptoms, newest day first.
  List<Symptom> get recent => List.unmodifiable(_recent);
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get lastError => _lastError;
  int get revision => _revision;
  bool get isEmpty => _recent.isEmpty;

  /// Symptoms recorded on a specific day.
  List<Symptom> on(DateTime date) {
    final day = dateOnly(date);
    return _recent.where((s) => s.date == day).toList();
  }

  /// Days in a month that carry at least one symptom, for calendar markers.
  Set<DateTime> markerDays() => {
        for (final symptom in _recent) dateOnly(symptom.date),
      };

  /// One line for the Settings row, phrased as a record rather than a status.
  String get summary {
    if (_recent.isEmpty) return 'Nothing recorded';
    final days = markerDays().length;
    return days == 1 ? 'Recorded on 1 day' : 'Recorded on $days days';
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final today = dateOnly(DateTime.now());
      _recent = await _database.getSymptomsBetween(
        today.subtract(const Duration(days: windowDays)),
        today,
      );
      _isLoaded = true;
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not load symptoms: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Records or updates a symptom for a day.
  ///
  /// Returns false for a future date, because a symptom is something that has
  /// happened rather than something planned.
  ///
  /// [replacing] is the entry being corrected. Rows are unique per day and kind,
  /// so re-saving the same kind on the same day updates it in place; changing
  /// either means the old row has to go, or the correction would leave a
  /// duplicate behind that the user never intended to keep.
  Future<bool> log({
    required DateTime date,
    required SymptomKind kind,
    int severity = 2,
    String? note,
    Symptom? replacing,
  }) async {
    final day = dateOnly(date);
    if (day.isAfter(dateOnly(DateTime.now()))) {
      _lastError = 'A symptom cannot be recorded for a future day.';
      notifyListeners();
      return false;
    }
    if (severity < 1 || severity > 3) {
      _lastError = 'Choose how bad it was.';
      notifyListeners();
      return false;
    }

    try {
      // A correction replaces the row it started from, whatever changed: the
      // day, the kind, or only the severity. Deleting first means the table
      // holds one row per entry rather than a second one the user never asked
      // for, and there is no unique index to lean on.
      final replacesId = replacing?.id;
      if (replacesId != null) {
        await _database.deleteSymptom(replacesId);
      }
      await _database.upsertSymptom(
        Symptom(
          date: day,
          kind: kind,
          severity: severity,
          note: (note == null || note.trim().isEmpty) ? null : note.trim(),
          createdAt: DateTime.now(),
        ),
      );
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not save that: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _database.deleteSymptom(id);
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not remove that: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAll() async {
    try {
      await _database.deleteAllSymptoms();
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not clear symptoms: $error';
      notifyListeners();
      return false;
    }
  }
}
