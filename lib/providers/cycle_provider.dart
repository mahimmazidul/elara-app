import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../data/date_keys.dart';
import '../data/models/cycle_entry.dart';

/// Owns the list of recorded periods.
///
/// The database is the source of truth: after every mutation this reloads from
/// sqflite rather than patching the in-memory list, so the provider can never
/// drift from what is stored (for example after an upsert that replaced a row
/// and gave it a new id).
class CycleProvider extends ChangeNotifier {
  CycleProvider({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  List<CycleEntry> _cycles = const [];
  bool _isLoading = false;
  String? _lastError;

  /// Bumped on every successful mutation, so dependent providers can refresh.
  int _revision = 0;

  /// Recorded periods, oldest first.
  List<CycleEntry> get cycles => List.unmodifiable(_cycles);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  int get revision => _revision;

  bool get isEmpty => _cycles.isEmpty;
  int get count => _cycles.length;
  CycleEntry? get latest => _cycles.isEmpty ? null : _cycles.last;

  /// Completed cycle lengths in days, oldest first.
  List<int> get completedLengths {
    final lengths = <int>[];
    for (var i = 1; i < _cycles.length; i++) {
      final length = daysBetween(_cycles[i - 1].startDate, _cycles[i].startDate);
      if (length > 0) lengths.add(length);
    }
    return lengths;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _cycles = await _database.getAllCycles();
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not load cycles: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// The shortest interval treated as a new cycle rather than a correction.
  ///
  /// Ten days is well inside the range a real cycle can take, so it only
  /// catches entries that are impossible as bleed starts of separate cycles.
  static const int minimumPlausibleCycleDays = 10;

  /// Records a period start.
  ///
  /// Logging the same date twice updates the duration instead of failing on the
  /// unique constraint, which is what a user tapping the same day twice means.
  /// Returns the stored entry, or null if the write failed (see [lastError]).
  Future<CycleEntry?> addCycle({
    required DateTime startDate,
    int? duration,
  }) async {
    if (duration != null && duration < 1) {
      _lastError = 'A period duration must be at least one day.';
      notifyListeners();
      return null;
    }

    final day = dateOnly(startDate);
    if (day.isAfter(dateOnly(DateTime.now()))) {
      // A future start would make every downstream "days until" figure negative
      // in a way the engine cannot interpret.
      _lastError = 'A period cannot start in the future.';
      notifyListeners();
      return null;
    }

    // A start too soon after the previous one is almost always a mistap or a
    // duplicate entry — spotting days, or the same bleed tapped twice. It is
    // refused with an explanation rather than quietly accepted, because one
    // implausible interval distorts every forecast that follows it.
    final previous = _latestBefore(day);
    if (previous != null) {
      final gap = daysBetween(previous.startDate, day);
      if (gap > 0 && gap < minimumPlausibleCycleDays) {
        _lastError =
            'That is only $gap '
            '${gap == 1 ? 'day' : 'days'} after the last start on '
            '${_formatShort(previous.startDate)}. If this is the same period, '
            'change the earlier date instead.';
        notifyListeners();
        return null;
      }
    }

    try {
      final stored = await _database.upsertCycle(
        CycleEntry(startDate: day, duration: duration),
      );
      await load();
      _revision++;
      _lastError = null;
      return stored;
    } catch (error) {
      _lastError = 'Could not save the period: $error';
      notifyListeners();
      return null;
    }
  }

  /// The most recent recorded start strictly before [day], if any.
  CycleEntry? _latestBefore(DateTime day) {
    CycleEntry? best;
    for (final entry in _cycles) {
      if (entry.startDate.isBefore(day) &&
          (best == null || entry.startDate.isAfter(best.startDate))) {
        best = entry;
      }
    }
    return best;
  }

  static String _formatShort(DateTime date) => '${date.day}/${date.month}';

  /// Updates the duration of an existing entry.
  Future<bool> updateDuration(int id, int? duration) async {
    if (duration != null && duration < 1) {
      _lastError = 'A period duration must be at least one day.';
      notifyListeners();
      return false;
    }
    try {
      final existing = await _database.getCycleById(id);
      if (existing == null) {
        _lastError = 'That period no longer exists.';
        notifyListeners();
        return false;
      }
      await _database.updateCycle(
        existing.copyWith(
          duration: duration,
          clearDuration: duration == null,
        ),
      );
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not update the period: $error';
      notifyListeners();
      return false;
    }
  }

  /// Moves a recorded start to a different day.
  ///
  /// This is the correction path the app was missing: a date entered a day out
  /// could previously only be deleted and re-entered, which loses the row and
  /// makes the calendar look like nothing ever happened. The same guards as
  /// [addCycle] apply, plus a collision check, because `start_date` is unique
  /// and a silent merge of two starts would be worse than a refusal.
  Future<bool> moveStartDate(int id, DateTime newStartDate) async {
    final day = dateOnly(newStartDate);
    if (day.isAfter(dateOnly(DateTime.now()))) {
      _lastError = 'A period cannot start in the future.';
      notifyListeners();
      return false;
    }

    try {
      final existing = await _database.getCycleById(id);
      if (existing == null) {
        _lastError = 'That period no longer exists.';
        notifyListeners();
        return false;
      }
      if (day == existing.startDate) {
        // Nothing to do, and not an error.
        _lastError = null;
        return true;
      }

      final collision = await _database.getCycleByStartDate(day);
      if (collision != null && collision.id != id) {
        _lastError = 'There is already a period recorded on that date.';
        notifyListeners();
        return false;
      }

      await _database.updateCycle(existing.copyWith(startDate: day));
      await load();
      _revision++;
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = 'Could not move that date: $error';
      notifyListeners();
      return false;
    }
  }

  /// The recorded start on [date], if any. Used by the day sheet to decide
  /// whether it is offering a correction or just a projection.
  CycleEntry? entryOn(DateTime date) {
    final day = dateOnly(date);
    for (final cycle in _cycles) {
      if (cycle.startDate == day) return cycle;
    }
    return null;
  }

  Future<bool> deleteCycle(int id) async {
    try {
      await _database.deleteCycle(id);
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not delete the period: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCycleByStartDate(DateTime startDate) async {
    try {
      await _database.deleteCycleByStartDate(startDate);
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not delete the period: $error';
      notifyListeners();
      return false;
    }
  }

  /// Clears all history. Intended for an explicit, confirmed user action.
  Future<bool> deleteAll() async {
    try {
      await _database.deleteAllCycles();
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not clear the cycle history: $error';
      notifyListeners();
      return false;
    }
  }
}
