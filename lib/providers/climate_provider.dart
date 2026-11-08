import 'package:flutter/foundation.dart';

import '../data/models/climate_snapshot.dart';
import '../services/climate_service.dart';

/// Holds today's environmental snapshot for the UI.
///
/// [ClimateService] never throws, so this provider's error state exists only
/// for genuinely unexpected failures elsewhere in the chain; a failed weather
/// call shows up as a snapshot with [ClimateSnapshot.isFallback] true instead.
class ClimateProvider extends ChangeNotifier {
  ClimateProvider({ClimateService? climateService})
      : _service = climateService ?? ClimateService();

  final ClimateService _service;

  ClimateSnapshot? _snapshot;
  bool _isLoading = false;
  String? _lastError;

  ClimateSnapshot? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// True when the current values are seasonal estimates, not live readings.
  bool get isFallback => _snapshot?.isFallback ?? false;

  /// Loads today's climate, using the three-hour cache when it is fresh.
  Future<ClimateSnapshot?> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _snapshot = await _service.getTodayClimate();
      _lastError = null;
    } catch (error) {
      // Defensive only: getTodayClimate is contracted not to throw.
      _lastError = 'Could not read the weather: $error';
      _snapshot ??= ClimateSnapshot.seasonalFallback(DateTime.now());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _snapshot;
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
