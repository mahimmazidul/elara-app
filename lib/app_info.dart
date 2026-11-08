/// Static application identity, in one place.
///
/// [version] mirrors `version:` in pubspec.yaml. It is duplicated here rather
/// than read at runtime because that would need `package_info_plus`, which is
/// not in the dependency list; keep the two in step when the version bumps.
class AppInfo {
  const AppInfo._();

  static const String name = 'Elara';
  static const String version = '1.0.0+1';
  static const String license = 'AGPL-3.0';
  static const String repositoryUrl =
      'https://github.com/mahimmazidul/elara-app';
  static const String engineUrl =
      'https://github.com/mahimmazidul/elara-core';

  static const String tagline =
      'An offline cycle companion. Nothing leaves this phone.';
}
