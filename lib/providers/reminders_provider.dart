import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../data/date_keys.dart';
import '../data/models/care_reminder.dart';

/// Owns the `care_reminders` table.
///
/// The window is the same sixty days the symptom provider keeps in memory: enough
/// for the calendar's month view and for "what is coming up", small enough that a
/// long history costs nothing.
class RemindersProvider extends ChangeNotifier {
  RemindersProvider({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  List<CareReminder> _window = const [];
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _lastError;
  int _revision = 0;

  /// Days of history kept in memory, matching [SymptomsProvider.windowDays].
  static const int windowDays = 60;

  /// How far ahead a reminder can be set. A year is generous for "the scan is in
  /// March" without pretending this is a calendar app.
  static const int horizonDays = 365;

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get lastError => _lastError;
  int get revision => _revision;
  bool get isEmpty => _window.isEmpty;

  /// Everything in the loaded window, earliest first.
  List<CareReminder> get all => List.unmodifiable(_window);

  /// Reminders on a specific day.
  List<CareReminder> on(DateTime date) {
    final day = dateOnly(date);
    return _window.where((r) => dateOnly(r.date) == day).toList();
  }

  /// Days in the window that carry at least one reminder, for calendar markers.
  Set<DateTime> markerDays() => {
        for (final reminder in _window) dateOnly(reminder.date),
      };

  /// The next few days' reminders, soonest first. Used by Today to say what is
  /// coming rather than what is happening.
  List<CareReminder> upcoming({DateTime? from, int days = 7}) {
    final start = dateOnly(from ?? DateTime.now());
    final end = start.add(Duration(days: days));
    return _window
        .where((r) => !r.done)
        .where((r) => !dateOnly(r.date).isBefore(start))
        .where((r) => !dateOnly(r.date).isAfter(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Unticked reminders for one day and the next, for the Today screen.
  List<CareReminder> get dueNow {
    final today = dateOnly(DateTime.now());
    return _window
        .where((r) => !r.done)
        .where((r) => !dateOnly(r.date).isAfter(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final today = dateOnly(DateTime.now());
      _window = await _database.getRemindersBetween(
        today.subtract(const Duration(days: windowDays)),
        today.add(const Duration(days: horizonDays)),
      );
      _isLoaded = true;
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not load reminders: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> add({
    required DateTime date,
    required String title,
    String? note,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      _lastError = 'Write what you want to remember.';
      notifyListeners();
      return false;
    }
    final day = dateOnly(date);
    final today = dateOnly(DateTime.now());
    if (day.isBefore(today.subtract(const Duration(days: windowDays))) ||
        day.isAfter(today.add(const Duration(days: horizonDays)))) {
      _lastError = 'That date is outside the range Elara keeps.';
      notifyListeners();
      return false;
    }

    try {
      await _database.insertReminder(
        CareReminder(
          date: day,
          title: trimmed,
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

  Future<bool> update(CareReminder reminder) async {
    if (reminder.title.trim().isEmpty) {
      _lastError = 'Write what you want to remember.';
      notifyListeners();
      return false;
    }
    try {
      await _database.updateReminder(
        reminder.copyWith(
          title: reminder.title.trim(),
          note: (reminder.note == null || reminder.note!.trim().isEmpty)
              ? null
              : reminder.note!.trim(),
          clearNote: reminder.note == null || reminder.note!.trim().isEmpty,
        ),
      );
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not save the change: $error';
      notifyListeners();
      return false;
    }
  }

  /// Ticks or unticks a reminder.
  Future<bool> setDone(CareReminder reminder, bool done) =>
      update(reminder.copyWith(done: done));

  Future<bool> delete(int id) async {
    try {
      await _database.deleteReminder(id);
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
      await _database.deleteAllReminders();
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not clear reminders: $error';
      notifyListeners();
      return false;
    }
  }

  /// One line for the Settings row.
  String get summary {
    final pending = _window.where((r) => !r.done).length;
    if (pending == 0) return 'Nothing planned';
    return pending == 1 ? '1 thing planned' : '$pending things planned';
  }
}
