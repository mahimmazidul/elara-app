import 'package:flutter/foundation.dart';

import '../app_info.dart';
import '../services/update_service.dart';

/// Where a check has got to.
enum UpdateStatus {
  /// Nothing has been asked for yet in this session.
  idle,

  /// A request is in flight.
  checking,

  /// The installed build is current.
  current,

  /// A newer release exists.
  available,

  /// The check could not produce an answer. Never shown as "up to date".
  failed,
}

/// Holds the result of the update check.
///
/// Deliberately small and manual by default: nothing here runs unless the user
/// taps the row, or has switched automatic checking on. The app never downloads
/// or installs a release itself — it can only offer the link.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    UpdateService? service,
    String? installedVersion,
    DateTime Function()? clock,
  })  : _service = service ?? UpdateService(),
        installedVersion = installedVersion ?? AppInfo.version,
        _clock = clock ?? DateTime.now;

  final UpdateService _service;
  final DateTime Function() _clock;

  /// The version this build reports, with its build number, e.g. `1.2.0+6`.
  /// Read from the app's own metadata rather than typed into a screen.
  final String installedVersion;

  UpdateStatus _status = UpdateStatus.idle;
  ReleaseInfo? _release;
  String? _message;
  bool _isOffline = false;
  DateTime? _lastCheckedAt;

  UpdateStatus get status => _status;
  ReleaseInfo? get release => _release;
  String? get message => _message;

  /// True when the last failure was a network one rather than a bad response.
  bool get isOffline => _isOffline;

  DateTime? get lastCheckedAt => _lastCheckedAt;

  /// The installed version without build metadata, for display and comparison.
  String get displayVersion {
    final plus = installedVersion.indexOf('+');
    return plus == -1 ? installedVersion : installedVersion.substring(0, plus);
  }

  /// The build number after `+`, or null when the metadata has none.
  String? get buildNumber {
    final plus = installedVersion.indexOf('+');
    if (plus == -1 || plus == installedVersion.length - 1) return null;
    return installedVersion.substring(plus + 1);
  }

  bool get isChecked =>
      _status == UpdateStatus.current || _status == UpdateStatus.available;

  Future<void> check() async {
    if (_status == UpdateStatus.checking) return;
    _status = UpdateStatus.checking;
    _message = null;
    _isOffline = false;
    notifyListeners();

    final result = await _service.check(installedVersion: installedVersion);
    _lastCheckedAt = _clock();

    switch (result) {
      case UpdateAvailable(:final release, :final isNewerThanInstalled):
        _release = release;
        _status = isNewerThanInstalled
            ? UpdateStatus.available
            : UpdateStatus.current;
        _message = null;
      case UpdateCurrent(:final latestVersion):
        _release = null;
        _status = UpdateStatus.current;
        _message = latestVersion.toString();
      case UpdateFailed(:final reason, :final isOffline):
        _release = null;
        _status = UpdateStatus.failed;
        _message = reason;
        _isOffline = isOffline;
    }
    notifyListeners();
  }

  /// One line for the Settings row.
  String get summary {
    switch (_status) {
      case UpdateStatus.idle:
        return 'Not checked yet';
      case UpdateStatus.checking:
        return 'Checking…';
      case UpdateStatus.current:
        return 'Up to date';
      case UpdateStatus.available:
        final version = _release?.version.toString();
        return version == null ? 'A newer release is out' : 'Version $version is out';
      case UpdateStatus.failed:
        return _isOffline ? 'Could not check — offline' : 'Check failed';
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
