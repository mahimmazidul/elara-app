import 'package:material_ui/material_ui.dart';

import '../data/database_helper.dart';
import '../data/models/cycle_mode.dart';
import 'settings_keys.dart';

/// Owns the key/value `settings` table and exposes typed accessors.
///
/// Every setter writes through to sqflite before notifying, so a widget that
/// rebuilds after a toggle is showing state that is already persisted. If the
/// write fails the in-memory value is left untouched and [lastError] is set, so
/// the UI cannot end up displaying a preference that was never saved.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  Map<String, String> _values = const {};
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _lastError;

  /// Increments on every successful change; lets dependent providers detect
  /// that settings were written without diffing the whole map.
  int _revision = 0;

  Map<String, String> get values => Map.unmodifiable(_values);
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get lastError => _lastError;
  int get revision => _revision;

  /// Reads all settings. Safe to call more than once.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _values = await _database.getAllSettings();
      _isLoaded = true;
      _lastError = null;
    } catch (error) {
      _lastError = 'Could not read settings: $error';
      // Fall back to defaults so the app is still usable.
      _values = {
        ...DatabaseHelper.defaultSettings,
        ..._values,
      };
      _isLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ typed reads --

  /// Latitude used for weather lookups, in decimal degrees.
  double get latitude => _readDouble(
        SettingsKeys.latitude,
        SettingsKeys.defaultLatitude,
      );

  /// Longitude used for weather lookups, in decimal degrees.
  double get longitude => _readDouble(
        SettingsKeys.longitude,
        SettingsKeys.defaultLongitude,
      );

  /// The place the coordinates stand for, empty when they were typed by hand.
  String get locationLabel => _values[SettingsKeys.locationLabel] ?? '';

  /// What to show for the location: the district name, or the numbers.
  String get locationSummary {
    final label = locationLabel;
    if (label.isNotEmpty) return label;
    return '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
  }

  ThemeMode get themeMode {
    switch (_values[SettingsKeys.themeMode]) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  /// Stored form of [themeMode], e.g. `system`.
  String get themeModeKey =>
      _values[SettingsKeys.themeMode] ?? SettingsKeys.defaultThemeMode;

  bool get notificationsEnabled => _readBool(
        SettingsKeys.notificationEnabled,
        SettingsKeys.defaultNotificationEnabled,
      );

  double _readDouble(String key, double fallback) {
    final raw = _values[key];
    if (raw == null) return fallback;
    final parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite) return fallback;
    return parsed;
  }

  /// Per-type notification switches. Each falls back to its own default when
  /// the key has never been written, so an existing install gains the new
  /// switches without a migration.
  bool get notifyDailyBriefing => _readBool(
        SettingsKeys.notifyDailyBriefing,
        SettingsKeys.defaultNotifyDailyBriefing,
      );

  bool get notifyPmsWarning => _readBool(
        SettingsKeys.notifyPmsWarning,
        SettingsKeys.defaultNotifyPmsWarning,
      );

  bool get notifyOvulationWindow => _readBool(
        SettingsKeys.notifyOvulationWindow,
        SettingsKeys.defaultNotifyOvulationWindow,
      );

  bool get notifyPeriodStart => _readBool(
        SettingsKeys.notifyPeriodStart,
        SettingsKeys.defaultNotifyPeriodStart,
      );

  bool get notifyClimateSpike => _readBool(
        SettingsKeys.notifyClimateSpike,
        SettingsKeys.defaultNotifyClimateSpike,
      );

  /// How many of the five individual reminders are switched on.
  ///
  /// The settings hub shows this so the Notifications row says something
  /// useful before it is opened, rather than repeating the word "Notifications"
  /// back at the reader.
  int get enabledReminderCount => [
        notifyDailyBriefing,
        notifyPmsWarning,
        notifyOvulationWindow,
        notifyPeriodStart,
        notifyClimateSpike,
      ].where((on) => on).length;

  /// True only when the user has asked for reminder text to be specific.
  bool get notifyPreviewDetails => _readBool(
        SettingsKeys.notifyPreviewDetails,
        SettingsKeys.defaultNotifyPreviewDetails,
      );

  /// Whether Elara checks for a newer release when it starts.
  bool get updatesAutoCheck => _readBool(
        SettingsKeys.updatesAutoCheck,
        SettingsKeys.defaultUpdatesAutoCheck,
      );

  Future<bool> setUpdatesAutoCheck(bool value) =>
      setValue(SettingsKeys.updatesAutoCheck, value ? 'true' : 'false');

  Future<bool> setNotifyPreviewDetails(bool value) => setValue(
        SettingsKeys.notifyPreviewDetails,
        value ? 'true' : 'false',
      );

  Future<bool> setNotifyDailyBriefing(bool value) => setValue(
        SettingsKeys.notifyDailyBriefing,
        value ? 'true' : 'false',
      );

  Future<bool> setNotifyPmsWarning(bool value) => setValue(
        SettingsKeys.notifyPmsWarning,
        value ? 'true' : 'false',
      );

  Future<bool> setNotifyOvulationWindow(bool value) => setValue(
        SettingsKeys.notifyOvulationWindow,
        value ? 'true' : 'false',
      );

  Future<bool> setNotifyPeriodStart(bool value) => setValue(
        SettingsKeys.notifyPeriodStart,
        value ? 'true' : 'false',
      );

  Future<bool> setNotifyClimateSpike(bool value) => setValue(
        SettingsKeys.notifyClimateSpike,
        value ? 'true' : 'false',
      );

  // ------------------------------------------------------------- cycle mode --

  /// Whether Elara is predicting, and if not, why. See [CycleMode].
  CycleMode get cycleMode =>
      CycleMode.fromStorageKey(_values[SettingsKeys.cycleMode]);

  /// The stated reason for a pause, if any. Never required.
  PauseReason? get pauseReason =>
      PauseReason.fromStorageKey(_values[SettingsKeys.pauseReason]);

  /// The day a pause was declared, if one was recorded.
  DateTime? get pauseSince {
    final raw = _values[SettingsKeys.pauseSince];
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Switches the mode, keeping the audit trail the screens need.
  ///
  /// Leaving `predicting` records the day it began, so the panel can say how
  /// long the app has been quiet rather than implying it has been broken.
  /// Returning to `predicting` clears both pause fields: a stale reason shown
  /// after someone has resumed would be a sentence about her body that she has
  /// already told the app is no longer true.
  Future<bool> setCycleMode(CycleMode mode, {
    PauseReason? reason,
    DateTime? since,
  }) async {
    if (mode.predicts) {
      final ok = await setValue(SettingsKeys.cycleMode, mode.storageKey);
      if (!ok) return false;
      await setValue(SettingsKeys.pauseReason, '');
      await setValue(SettingsKeys.pauseSince, '');
      return true;
    }

    final started = (since ?? DateTime.now());
    final day = '${started.year.toString().padLeft(4, '0')}-'
        '${started.month.toString().padLeft(2, '0')}-'
        '${started.day.toString().padLeft(2, '0')}';
    try {
      await _database.setSettings({
        SettingsKeys.cycleMode: mode.storageKey,
        SettingsKeys.pauseReason: reason?.storageKey ?? '',
        SettingsKeys.pauseSince: day,
      });
      _values = {
        ..._values,
        SettingsKeys.cycleMode: mode.storageKey,
        SettingsKeys.pauseReason: reason?.storageKey ?? '',
        SettingsKeys.pauseSince: day,
      };
      _revision++;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = 'Could not save the cycle mode: $error';
      notifyListeners();
      return false;
    }
  }

  bool _readBool(String key, bool fallback) {
    final raw = _values[key];
    if (raw == null) return fallback;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return fallback;
  }

  // ---------------------------------------------------------------- writes --

  Future<bool> setThemeMode(ThemeMode mode) {
    final stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return setValue(SettingsKeys.themeMode, stored);
  }

  Future<bool> setNotificationsEnabled(bool enabled) =>
      setValue(SettingsKeys.notificationEnabled, enabled ? 'true' : 'false');

  /// Stores the coordinates used for weather and air-quality lookups.
  /// Saves the coordinate, and the place it came from when there is one.
  ///
  /// [label] is what the district picker knows and a typed coordinate does not;
  /// passing null clears it, so a manual entry stops claiming to be a district.
  Future<bool> setLocation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    if (!latitude.isFinite || !longitude.isFinite) {
      _lastError = 'Coordinates must be finite numbers.';
      notifyListeners();
      return false;
    }
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      _lastError = 'Coordinates are out of range.';
      notifyListeners();
      return false;
    }
    try {
      final write = <String, String>{
        SettingsKeys.latitude: latitude.toString(),
        SettingsKeys.longitude: longitude.toString(),
        SettingsKeys.locationLabel: label ?? '',
      };
      await _database.setSettings(write);
      _values = {..._values, ...write};
      _revision++;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = 'Could not save location: $error';
      notifyListeners();
      return false;
    }
  }

  /// Writes any setting, then notifies. Returns false if persistence failed.
  Future<bool> setValue(String key, String value) async {
    if (key.trim().isEmpty) {
      _lastError = 'A settings key cannot be empty.';
      notifyListeners();
      return false;
    }
    try {
      await _database.setSetting(key, value);
      _values = {..._values, key: value};
      _revision++;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = 'Could not save "$key": $error';
      notifyListeners();
      return false;
    }
  }
}
