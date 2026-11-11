/// Static application identity, in one place.
///
/// [version] must mirror `version:` in pubspec.yaml. It is duplicated here
/// rather than read at runtime, which would need `package_info_plus`. The
/// duplication had drifted (Settings showed 1.0.0 while the release was 1.1.0),
/// so `test/app_info_test.dart` now fails the build if the two disagree.
class AppInfo {
  const AppInfo._();

  static const String name = 'Elara';
  static const String version = '2.2.0+11';
  static const String license = 'AGPL-3.0';
  static const String repositoryUrl =
      'https://github.com/mahimmazidul/elara-app';
  static const String engineUrl = 'https://github.com/mahimmazidul/elara-core';

  static const String tagline =
      'An offline companion for a cycle, and for the person living it.';
}
