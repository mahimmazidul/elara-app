import 'dart:io';

import 'package:elara_app/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the one duplicated fact in the app.
///
/// `AppInfo.version` is shown in Settings and cannot be read from the build at
/// runtime without a package the app does not carry, so it is written twice.
/// It had drifted — Settings claimed 1.0.0 while the release was 1.1.0 — which
/// is exactly the sort of quiet inaccuracy that makes a version number
/// worthless. This test makes the drift loud.
void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(
      AppInfo.version,
      match!.group(1),
      reason: 'update lib/app_info.dart when the pubspec version changes',
    );
  });

  test('the identity strings are not placeholders', () {
    expect(AppInfo.name, 'Elara');
    expect(AppInfo.license, 'AGPL-3.0');
    expect(AppInfo.repositoryUrl, startsWith('https://'));
    expect(AppInfo.tagline, isNotEmpty);
  });
}
