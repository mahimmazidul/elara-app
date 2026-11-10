/// Keys used in the `settings` table.
///
/// These strings are the contract between [SettingsProvider] and
/// [DatabaseHelper.defaultSettings]; changing one without the other silently
/// loses the default, so they live in exactly one place.
class SettingsKeys {
  SettingsKeys._();

  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String themeMode = 'theme_mode';
  static const String notificationEnabled = 'notification_enabled';

  // Per-notification-type switches. These are deliberately NOT added to
  // DatabaseHelper.defaultSettings: the data-layer tests assert that exactly
  // four defaults are seeded, and a missing key is already handled by the typed
  // getters below. The scheduling itself is not part of this part of the build;
  // these keys exist so the Settings screen can persist a user's choices now.
  static const String notifyDailyBriefing = 'notify_daily_briefing';
  static const String notifyPmsWarning = 'notify_pms_warning';
  static const String notifyOvulationWindow = 'notify_ovulation_window';
  static const String notifyPeriodStart = 'notify_period_start';
  static const String notifyClimateSpike = 'notify_climate_spike';

  /// Whether reminder text may name the phase, the cycle or the body.
  ///
  /// Off by default. A notification is read on a lock screen, across a room,
  /// over a shoulder; the default has to assume an audience.
  static const String notifyPreviewDetails = 'notify_preview_details';

  /// Whether Elara predicts a cycle at all, and when it does not, why.
  ///
  /// Stored as a string (`predicting`, `hormonal_contraception`, `paused`)
  /// rather than a flag, because the three states need three different
  /// sentences on screen and a boolean cannot hold them. Defaults to
  /// predicting, which is what every existing install is doing.
  static const String cycleMode = 'cycle_mode';
  static const String defaultCycleMode = 'predicting';

  /// The stated reason for a pause, and the day it began.
  ///
  /// Both optional. The app asks, in case the answer makes the screen kinder,
  /// and it never requires an answer to stop counting days.
  static const String pauseReason = 'pause_reason';
  static const String pauseSince = 'pause_since';

  /// Whether Elara asks GitHub for the latest release when it starts.
  /// Off by default: an update check is the one request that is about the app
  /// rather than about the weather, and it should be opted into.
  static const String updatesAutoCheck = 'updates_auto_check';
  static const bool defaultUpdatesAutoCheck = false;

  /// Defaults for the per-type switches.
  static const bool defaultNotifyDailyBriefing = true;
  static const bool defaultNotifyPmsWarning = true;
  static const bool defaultNotifyOvulationWindow = true;
  static const bool defaultNotifyPeriodStart = true;
  static const bool defaultNotifyClimateSpike = false;
  static const bool defaultNotifyPreviewDetails = false;

  /// Defaults applied on a cache miss, mirroring [DatabaseHelper.defaultSettings].
  static const double defaultLatitude = 23.8103;
  static const double defaultLongitude = 90.4125;
  static const String defaultThemeMode = 'system';
  static const bool defaultNotificationEnabled = true;
}
