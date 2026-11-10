import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../data/models/preference.dart';

/// Owns the `preferences` table and the two perspectives inside it.
///
/// The provider keeps one list rather than two, because the question the care
/// engine asks is "what do we know about her, and how strong is it", not "whose
/// screen are we on". It exposes the split only where the UI genuinely needs it:
/// the observation list the holder edits, and her answers.
class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  List<Preference> _all = const [];
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _lastError;

  /// Bumped on every successful mutation so the care engine recomputes.
  int _revision = 0;

  List<Preference> get all => List.unmodifiable(_all);
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get lastError => _lastError;
  int get revision => _revision;

  bool get isEmpty => _all.isEmpty;

  /// Observations the app holder recorded, newest first.
  List<Preference> get observations => List.unmodifiable(
        _all.where((p) => p.source == PreferenceSource.partnerObservation),
      );

  /// Answers she wrote herself.
  List<Preference> get herAnswers => List.unmodifiable(
        _all.where((p) => p.source == PreferenceSource.herAnswer),
      );

  /// Answers she chose to share. Everything else is withheld from suggestions,
  /// though — as the questionnaire says plainly — not from the phone's owner.
  List<Preference> get sharedAnswers => List.unmodifiable(
        _all.where((p) => p.isHerOwn && p.shared),
      );

  bool get hasSharedAnswers => sharedAnswers.isNotEmpty;

  /// One line for the Settings row, so the count is visible without opening the
  /// screen. Deliberately not a score of any kind.
  String get summary {
    if (_all.isEmpty) return 'Nothing recorded yet';
    final hers = herAnswers.length;
    final mine = observations.length;
    final parts = <String>[
      if (hers > 0) '$hers from her',
      if (mine > 0) '$mine from you',
    ];
    return parts.join(' \u00b7 ');
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _all = await _database.getAllPreferences();
      _isLoaded = true;
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not load preferences: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Records an observation by the app holder.
  ///
  /// Always [PreferenceStatus.unconfirmed] unless the holder marks it as
  /// confirmed after asking her: the app cannot verify an observation, so it
  /// must not present one as agreed.
  Future<bool> addObservation({
    required PreferenceCategory category,
    required String value,
    bool confirmedByHer = false,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _lastError = 'Write something first.';
      notifyListeners();
      return false;
    }
    return _write(
      Preference(
        category: category,
        value: trimmed,
        source: PreferenceSource.partnerObservation,
        status: confirmedByHer
            ? PreferenceStatus.confirmed
            : PreferenceStatus.unconfirmed,
        // An observation is visible to the person who made it by definition.
        shared: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Records one of her own answers from the questionnaire.
  Future<bool> addHerAnswer({
    required PreferenceCategory category,
    required String value,
    required bool share,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _lastError = 'Write something first.';
      notifyListeners();
      return false;
    }
    return _write(
      Preference(
        category: category,
        value: trimmed,
        source: PreferenceSource.herAnswer,
        // She wrote it, so it is confirmed by definition.
        status: PreferenceStatus.confirmed,
        shared: share,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<bool> _write(Preference preference) async {
    try {
      await _database.insertPreference(preference);
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not save: $error';
      notifyListeners();
      return false;
    }
  }

  /// Edits an existing entry, keeping its source and status unless changed.
  Future<bool> update(Preference preference) async {
    if (preference.value.trim().isEmpty) {
      _lastError = 'Write something first.';
      notifyListeners();
      return false;
    }
    try {
      await _database.updatePreference(
        preference.copyWith(value: preference.value.trim()),
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

  /// Changes whether one of her answers is shared with the partner.
  Future<bool> setShared(Preference preference, bool shared) async {
    if (!preference.isHerOwn) return false;
    return update(preference.copyWith(shared: shared));
  }

  /// Marks an observation as confirmed by her, after asking.
  Future<bool> confirm(Preference preference) async {
    return update(preference.copyWith(status: PreferenceStatus.confirmed));
  }

  Future<bool> delete(int id) async {
    try {
      await _database.deletePreference(id);
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
      await _database.deleteAllPreferences();
      await load();
      _revision++;
      return true;
    } catch (error) {
      _lastError = 'Could not clear preferences: $error';
      notifyListeners();
      return false;
    }
  }
}
