import 'package:flutter/widgets.dart';

import '../models/elara_result.dart';
import '../services/prediction_service.dart';

/// Holds the current [ElaraResult] and decides when to recompute it.
///
/// Recomputes on demand and when the app returns to the foreground: a cycle
/// position changes with the calendar date, so a stale result after an overnight
/// background is wrong even though nothing in the database changed.
///
/// Concurrent refreshes are collapsed — [refresh] returns the in-flight future
/// rather than starting a second pipeline run, which matters because a resume
/// event and a pull-to-refresh can arrive together.
class PredictionProvider extends ChangeNotifier with WidgetsBindingObserver {
  PredictionProvider({PredictionService? predictionService})
      : _service = predictionService ?? PredictionService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final PredictionService _service;

  ElaraResult? _result;
  bool _isLoading = false;
  String? _lastError;
  DateTime? _lastUpdated;
  Future<ElaraResult?>? _inFlight;

  /// Revisions of the providers this one depends on, so it can notice that
  /// cycles or settings were written and quietly refresh.
  int _seenCycleRevision = -1;
  int _seenSettingsRevision = -1;

  /// Guards the deferred refresh against a provider disposed mid-frame.
  bool _disposed = false;

  ElaraResult? get result => _result;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasResult => _result != null;

  /// True when the user has no recorded cycles, so nothing can be predicted.
  bool get needsHistory => !_isLoading && _result == null && _lastError == null;

  /// Recomputes the prediction. Returns null when there is not enough history.
  Future<ElaraResult?> refresh({bool force = false}) async {
    final pending = _inFlight;
    if (pending != null && !force) return pending;

    final future = _run();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<ElaraResult?> _run() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _service.predict();
      _result = result;
      _lastUpdated = DateTime.now();
      _lastError = null;
      return result;
    } catch (error) {
      // Defensive only: PredictionService is contracted not to throw.
      _lastError = 'Could not update the prediction: $error';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call after cycles or settings change. Refreshes only when a revision has
  /// actually moved, so ordinary rebuilds cost nothing.
  Future<void> syncDependencies({
    required int cycleRevision,
    required int settingsRevision,
  }) async {
    final changed = cycleRevision != _seenCycleRevision ||
        settingsRevision != _seenSettingsRevision;
    _seenCycleRevision = cycleRevision;
    _seenSettingsRevision = settingsRevision;
    if (!changed || _isLoading) return;

    // This is called from a ProxyProvider `update`, which runs during build.
    // Notifying listeners synchronously here would mark widgets dirty mid-build,
    // so defer the refresh until the current frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Not forced: if a refresh is already running, let it finish.
      refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }
}
