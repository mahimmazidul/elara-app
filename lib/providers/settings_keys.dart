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

  /// Defaults applied on a cache miss, mirroring [DatabaseHelper.defaultSettings].
  static const double defaultLatitude = 23.8103;
  static const double defaultLongitude = 90.4125;
  static const String defaultThemeMode = 'system';
  static const bool defaultNotificationEnabled = true;
}
