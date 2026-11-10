import 'dart:convert';

import 'package:elara_app/providers/update_provider.dart';
import 'package:elara_app/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Version comparison and the update check.
///
/// The comparison is the part that decides whether someone is told there is a
/// newer build, so it is tested against the cases a string compare gets wrong:
/// `1.10.0` against `1.9.0`, and a pre-release against its release.
void main() {
  group('semantic versions', () {
    SemanticVersion v(String raw) {
      final parsed = SemanticVersion.tryParse(raw);
      expect(parsed, isNotNull, reason: 'could not parse $raw');
      return parsed!;
    }

    test('compares numerically, not as strings', () {
      expect(v('1.10.0') > v('1.9.0'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('1.2.10') > v('1.2.9'), isTrue);
      expect(v('1.2.3') == v('1.2.3'), isTrue);
    });

    test('accepts a leading v and a build number', () {
      expect(v('v1.2.3') == v('1.2.3'), isTrue);
      expect(v('1.2.3+6') == v('1.2.3'), isTrue);
      expect(v('1.2.3+6').build, '6');
    });

    test('a pre-release sorts below its release', () {
      expect(v('1.3.0-beta.1') < v('1.3.0'), isTrue);
      expect(v('1.3.0-beta.2') > v('1.3.0-beta.1'), isTrue);
      expect(v('1.3.0-beta.1') > v('1.2.9'), isTrue);
      // Numeric identifiers sort below alphanumeric ones, per SemVer.
      expect(v('1.3.0-1') < v('1.3.0-alpha'), isTrue);
    });

    test('rejects what is not a version', () {
      for (final bad in ['', 'latest', '1.2', 'v1', 'release-1.2.3']) {
        expect(SemanticVersion.tryParse(bad), isNull, reason: bad);
      }
    });

    test('isPreRelease reflects a suffix', () {
      expect(v('1.2.0').isPreRelease, isFalse);
      expect(v('1.2.0-rc.1').isPreRelease, isTrue);
    });
  });

  group('check()', () {
    Map<String, dynamic> payload({
      String tag = 'v1.3.0',
      bool prerelease = false,
      String body = 'Notes for 1.3.0',
      List<Map<String, Object>> assets = const [],
    }) =>
        {
          'tag_name': tag,
          'name': 'Elara $tag',
          'body': body,
          'html_url': 'https://github.com/mahimmazidul/elara-app/releases/tag/$tag',
          'prerelease': prerelease,
          'published_at': '2026-11-01T10:00:00Z',
          'assets': assets,
        };

    UpdateService withResponse(
      String body, {
      int status = 200,
      Duration delay = Duration.zero,
    }) =>
        UpdateService(
          httpClient: MockClient((_) async {
            if (delay > Duration.zero) await Future<void>.delayed(delay);
            return http.Response(body, status);
          }),
        );

    test('reports a newer release', () async {
      final service = withResponse(jsonEncode(payload()));
      final result = await service.check(installedVersion: '1.2.0+6');

      expect(result, isA<UpdateAvailable>());
      final available = result as UpdateAvailable;
      expect(available.release.version.toString(), '1.3.0');
      expect(available.release.notes, 'Notes for 1.3.0');
      expect(available.isNewerThanInstalled, isTrue);
    });

    test('reports the installed build as current', () async {
      final service = withResponse(jsonEncode(payload(tag: 'v1.2.0')));
      final result = await service.check(installedVersion: '1.2.0+6');

      expect(result, isA<UpdateCurrent>());
    });

    test('an older published release is not offered as an update', () async {
      final service = withResponse(jsonEncode(payload(tag: 'v1.1.0')));
      final result = await service.check(installedVersion: '1.2.0+6');

      expect(result, isA<UpdateCurrent>());
    });

    test('a pre-release is never offered to a stable build', () async {
      final service = withResponse(
        jsonEncode(payload(tag: 'v1.4.0-rc.1', prerelease: true)),
      );
      final result = await service.check(installedVersion: '1.2.0+6');

      expect(result, isA<UpdateCurrent>());
    });

    test('parses APK assets and keeps only github.com links', () async {
      final service = withResponse(
        jsonEncode(
          payload(
            assets: [
              {
                'name': 'elara-1.3.0-arm64-v8a.apk',
                'browser_download_url':
                    'https://github.com/mahimmazidul/elara-app/releases/download/v1.3.0/elara-1.3.0-arm64-v8a.apk',
                'size': 23700000,
              },
              {
                'name': 'elara-1.3.0-universal.apk',
                'browser_download_url':
                    'https://github.com/mahimmazidul/elara-app/releases/download/v1.3.0/elara-1.3.0-universal.apk',
                'size': 0,
              },
              {
                'name': 'elara-1.3.0-arm64-v8a.apk',
                'browser_download_url': 'http://elsewhere.example/file.apk',
                'size': 10,
              },
            ],
          ),
        ),
      );

      final result = await service.check(installedVersion: '1.2.0') as UpdateAvailable;
      final apks = result.release.assets.where((a) => a.isApk).toList();

      expect(apks, hasLength(2));
      expect(result.release.arm64Apk?.name, 'elara-1.3.0-arm64-v8a.apk');
      expect(result.release.universalApk?.name,
          'elara-1.3.0-universal.apk');
      // arm must not pick up the arm64 build and call it 32-bit.
      expect(result.release.armApk, isNull);
      expect(apks.first.sizeLabel, '22.6 MB');
    });

    test('a network failure is a failure, not "up to date"', () async {
      final service = UpdateService(
        httpClient: MockClient((_) async => throw const SocketishError()),
      );
      final result = await service.check(installedVersion: '1.2.0');

      expect(result, isA<UpdateFailed>());
      expect((result as UpdateFailed).isOffline, isTrue);
    });

    test('a timeout is reported as offline', () async {
      final service = withResponse(
        jsonEncode(payload()),
        delay: const Duration(milliseconds: 200),
      );
      final result = await UpdateService(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response(jsonEncode(payload()), 200);
        }),
        timeout: const Duration(milliseconds: 20),
      ).check(installedVersion: '1.2.0');

      expect(result, isA<UpdateFailed>());
      expect((result as UpdateFailed).isOffline, isTrue);
      service.dispose();
    });

    test('rate limiting says so rather than pretending to be current',
        () async {
      final service = withResponse('{}', status: 403);
      final result = await service.check(installedVersion: '1.2.0');

      expect(result, isA<UpdateFailed>());
      expect((result as UpdateFailed).reason, contains('rate-limiting'));
    });

    test('a missing release is explained', () async {
      final service = withResponse('{}', status: 404);
      final result = await service.check(installedVersion: '1.2.0');

      expect(result, isA<UpdateFailed>());
      expect((result as UpdateFailed).reason, contains('No published release'));
    });

    test('malformed JSON and a bad tag are both failures', () async {
      expect(
        await withResponse('not json').check(installedVersion: '1.2.0'),
        isA<UpdateFailed>(),
      );
      expect(
        await withResponse(jsonEncode(payload(tag: 'nightly')))
            .check(installedVersion: '1.2.0'),
        isA<UpdateFailed>(),
      );
    });

    test('an unreadable installed version does not guess', () async {
      final service = withResponse(jsonEncode(payload()));
      final result = await service.check(installedVersion: 'dev');

      expect(result, isA<UpdateFailed>());
    });

    test('the request carries no identity and no query', () async {
      late http.Request captured;
      final service = UpdateService(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(payload()), 200);
        }),
      );
      await service.check(installedVersion: '1.2.0');

      expect(captured.method, 'GET');
      expect(captured.url.toString(), UpdateService.latestReleaseUrl);
      expect(captured.url.query, isEmpty);
      expect(captured.url.pathSegments.last, 'latest');
      // Accept is the only header: no user agent naming a device, no token.
      expect(captured.headers.keys, ['Accept']);
      expect(captured.body, isEmpty);
    });
  });

  group('UpdateProvider', () {
    test('starts idle and not checked', () {
      final provider = UpdateProvider(
        service: UpdateService(
          httpClient: MockClient((_) async => http.Response('{}', 500)),
        ),
        installedVersion: '1.2.0+6',
      );

      expect(provider.status, UpdateStatus.idle);
      expect(provider.summary, 'Not checked yet');
      provider.dispose();
    });

    test('splits version and build number from the app metadata', () {
      final provider = UpdateProvider(
        service: UpdateService(
          httpClient: MockClient((_) async => http.Response('{}', 500)),
        ),
        installedVersion: '1.2.0+6',
      );

      expect(provider.displayVersion, '1.2.0');
      expect(provider.buildNumber, '6');
      provider.dispose();
    });

    test('a failure keeps the previous "current" answer out of the summary',
        () async {
      final provider = UpdateProvider(
        service: UpdateService(
          httpClient: MockClient((_) async => throw Exception('offline')),
        ),
        installedVersion: '1.2.0+6',
        clock: () => DateTime(2026, 11, 8, 9, 30),
      );

      await provider.check();

      expect(provider.status, UpdateStatus.failed);
      expect(provider.isOffline, isTrue);
      expect(provider.summary, 'Could not check — offline');
      expect(provider.lastCheckedAt, DateTime(2026, 11, 8, 9, 30));
      provider.dispose();
    });

    test('an available release is exposed with its notes', () async {
      final provider = UpdateProvider(
        service: UpdateService(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'tag_name': 'v1.3.0',
                'name': 'Elara 1.3.0',
                'body': 'What changed',
                'html_url': 'https://github.com/x/y/releases/tag/v1.3.0',
                'prerelease': false,
                'published_at': '2026-11-01T00:00:00Z',
                'assets': [],
              }),
              200,
            ),
          ),
        ),
        installedVersion: '1.2.0+6',
      );

      await provider.check();

      expect(provider.status, UpdateStatus.available);
      expect(provider.summary, 'Version 1.3.0 is out');
      expect(provider.release?.notes, 'What changed');
      provider.dispose();
    });
  });
}

/// Stands in for a transport error without depending on dart:io in a test that
/// must also run in a web-ish host.
class SocketishError implements Exception {
  const SocketishError();

  @override
  String toString() => 'Connection refused';
}
