import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A semantic version, as published in a release tag.
///
/// Only what Elara's own tags use is supported: `1.2.3` or `v1.2.3`, with an
/// optional pre-release suffix (`1.3.0-beta.1`) and build metadata after a
/// `+`. Comparison follows SemVer 2.0.0 precedence: numeric segments compare
/// numerically, and a pre-release version sorts *below* the release it leads to,
/// which is the detail a naive string comparison gets wrong.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = const [],
    this.build = '',
  });

  final int major;
  final int minor;
  final int patch;

  /// Dot-separated pre-release identifiers, e.g. `['beta', '1']`.
  final List<String> preRelease;

  /// Build metadata. Ignored for precedence, per the specification.
  final String build;

  bool get isPreRelease => preRelease.isNotEmpty;

  static final RegExp _pattern = RegExp(
    r'^[vV]?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.\-]+))?(?:\+([0-9A-Za-z.\-]+))?$',
  );

  /// Parses `1.2.3`, `v1.2.3`, `1.2.3-beta.2`, `1.2.3+6`, or `1.2.3-rc.1+7`.
  /// Returns null for anything else, including a bare `1.2`.
  static SemanticVersion? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      preRelease: match.group(4) == null
          ? const []
          : match.group(4)!.split('.'),
      build: match.group(5) ?? '',
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // A release outranks any pre-release of itself.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final length =
        preRelease.length < other.preRelease.length
            ? preRelease.length
            : other.preRelease.length;
    for (var i = 0; i < length; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      final aNumber = int.tryParse(a);
      final bNumber = int.tryParse(b);
      int result;
      if (aNumber != null && bNumber != null) {
        result = aNumber.compareTo(bNumber);
      } else if (aNumber != null) {
        result = -1; // numeric identifiers sort below alphanumeric ones
      } else if (bNumber != null) {
        result = 1;
      } else {
        result = a.compareTo(b);
      }
      if (result != 0) return result;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    final pre = preRelease.isEmpty ? '' : '-${preRelease.join('.')}';
    final meta = build.isEmpty ? '' : '+$build';
    return '$base$pre$meta';
  }
}

/// One downloadable asset attached to a release.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  final String name;
  final String downloadUrl;
  final int sizeBytes;

  /// Human-friendly size, e.g. `22.6 MB`.
  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// The APK for a given Android ABI, by the release workflow's naming.
  bool get isApk => name.toLowerCase().endsWith('.apk');
}

/// A published release, as far as the app needs to know about it.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    required this.assets,
    required this.isPreRelease,
    required this.publishedAt,
  });

  final String tag;
  final SemanticVersion version;
  final String name;

  /// Release notes, as Markdown. Shown as plain text.
  final String notes;

  /// The human-facing release page.
  final String htmlUrl;

  final List<ReleaseAsset> assets;
  final bool isPreRelease;
  final DateTime? publishedAt;

  /// The APK that suits an arm64 phone, if the release has one.
  ReleaseAsset? get arm64Apk => _apkFor('arm64');
  ReleaseAsset? get armApk => _apkFor('arm');
  ReleaseAsset? get universalApk => _apkFor('universal');

  ReleaseAsset? _apkFor(String abi) {
    for (final asset in assets) {
      final name = asset.name.toLowerCase();
      if (!asset.isApk) continue;
      if (abi == 'arm' && name.contains('arm64')) continue;
      if (name.contains(abi)) return asset;
    }
    return null;
  }
}

/// Result of one check, so the UI never has to interpret an exception.
sealed class UpdateResult {
  const UpdateResult();
}

/// A newer release exists.
class UpdateAvailable extends UpdateResult {
  const UpdateAvailable(this.release, {required this.isNewerThanInstalled});

  final ReleaseInfo release;
  final bool isNewerThanInstalled;
}

/// The installed version is current, or newer than anything published.
class UpdateCurrent extends UpdateResult {
  const UpdateCurrent(this.latestVersion);

  final SemanticVersion latestVersion;
}

/// The check did not produce an answer. Never treated as "up to date".
class UpdateFailed extends UpdateResult {
  const UpdateFailed(this.reason, {this.isOffline = false});

  final String reason;
  final bool isOffline;
}

/// Checks GitHub Releases for a newer build.
///
/// What it sends: one unauthenticated GET to the public releases endpoint. No
/// headers identifying the user or the device, no query parameters, and no
/// payload — the app has no accounts and this is the only request it makes that
/// is not about weather. What it does with the answer: compares tags, and shows
/// notes. It never downloads or installs anything itself.
class UpdateService {
  UpdateService({
    http.Client? httpClient,
    Duration? timeout,
  })  : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _timeout = timeout ?? const Duration(seconds: 12);

  final http.Client _http;
  final bool _ownsClient;
  final Duration _timeout;

  static const String latestReleaseUrl =
      'https://api.github.com/repos/mahimmazidul/elara-app/releases/latest';
  static const String releasesPageUrl =
      'https://github.com/mahimmazidul/elara-app/releases';

  /// Asks GitHub for the latest stable release and compares it with
  /// [installedVersion] (a `major.minor.patch` string, from the app's own
  /// metadata rather than a constant typed into this file).
  Future<UpdateResult> check({required String installedVersion}) async {
    final installed = SemanticVersion.tryParse(installedVersion);
    if (installed == null) {
      return const UpdateFailed(
        'Elara could not read its own version number, so it cannot compare it '
        'with the latest release.',
      );
    }

    try {
      final response = await _http.get(
        Uri.parse(latestReleaseUrl),
        headers: const {
          // Only what the API requires to return JSON. No user agent string
          // carrying a device name or an app install id.
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 404) {
        return const UpdateFailed(
          'No published release was found. This can happen before the first '
          'release is published.',
        );
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        return const UpdateFailed(
          'GitHub is rate-limiting update checks right now. Try again later.',
        );
      }
      if (response.statusCode != 200) {
        return UpdateFailed(
          'GitHub answered with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateFailed('The update response was not readable.');
      }

      final tag = decoded['tag_name'];
      if (tag is! String) {
        return const UpdateFailed('The latest release has no version tag.');
      }
      final latest = SemanticVersion.tryParse(tag);
      if (latest == null) {
        return UpdateFailed(
          'The latest release tag "$tag" is not a version number Elara can '
          'compare.',
        );
      }

      final isPreRelease = decoded['prerelease'] == true;
      final release = ReleaseInfo(
        tag: tag,
        version: latest,
        name: (decoded['name'] as String?)?.trim().isNotEmpty == true
            ? decoded['name'] as String
            : tag,
        notes: (decoded['body'] as String?)?.trim() ?? '',
        htmlUrl: (decoded['html_url'] as String?) ?? releasesPageUrl,
        isPreRelease: isPreRelease,
        publishedAt: DateTime.tryParse(
          (decoded['published_at'] as String?) ?? '',
        ),
        assets: _parseAssets(decoded['assets']),
      );

      // A pre-release is never offered as "newer" to someone on a stable
      // build: that would be an unrequested switch of channel.
      if (isPreRelease) return UpdateCurrent(latest);

      if (latest > installed) {
        return UpdateAvailable(release, isNewerThanInstalled: true);
      }
      return UpdateCurrent(latest);
    } on TimeoutException {
      return const UpdateFailed(
        'The update check timed out. Elara works the same offline.',
        isOffline: true,
      );
    } on FormatException {
      return const UpdateFailed('The update response could not be parsed.');
    } catch (error) {
      return UpdateFailed(
        'Could not reach GitHub: $error. Elara works the same offline.',
        isOffline: true,
      );
    }
  }

  static List<ReleaseAsset> _parseAssets(Object? raw) {
    if (raw is! List) return const [];
    final assets = <ReleaseAsset>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name'];
      final url = entry['browser_download_url'];
      if (name is! String || url is! String) continue;
      if (!url.startsWith('https://github.com/')) continue;
      assets.add(
        ReleaseAsset(
          name: name,
          downloadUrl: url,
          sizeBytes: (entry['size'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return assets;
  }

  void dispose() {
    if (_ownsClient) _http.close();
  }
}
