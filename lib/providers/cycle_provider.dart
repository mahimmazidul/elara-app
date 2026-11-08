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
