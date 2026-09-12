import 'package:flutter/foundation.dart';

import '../sky/sky_weather.dart';
import 'open_meteo_source.dart';
import 'weather_model.dart';
import 'weather_source.dart';

/// Weather cache and dispatch service.
///
/// Features:
/// - Source-agnostic (default Open-Meteo, switchable via string id)
/// - Caches last good observation
/// - Enforces staleness rule (> 3 hours old -> null SkyWeather, clear-looking)
/// - Emits change events so SkyStateSource can update immediately
class WeatherService extends ChangeNotifier {
  WeatherService({
    WeatherSource? defaultSource,
    Map<String, WeatherSource>? extraSources,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final s = defaultSource ?? OpenMeteoWeatherSource();
    _sources[s.id] = s;
    if (extraSources != null) {
      _sources.addAll(extraSources);
    }
    _activeSourceId = s.id;
  }

  final DateTime Function() _clock;
  final Map<String, WeatherSource> _sources = {};
  String _activeSourceId = 'open-meteo';
  WeatherObservation? _cached;
  int _request = 0;
  String? _location;
  bool _disposed = false;

  String get activeSourceId => _activeSourceId;
  WeatherObservation? get cachedObservation => _cached;
  bool matchesLocation(double latitude, double longitude) =>
      _location == null || _location == '$latitude,$longitude';

  /// Returns the current SkyWeather component for the 3D layer.
  /// Null if unobserved, or if the cached observation is > 3 hours old.
  SkyWeather? get currentSkyWeather => _cached?.activeSkyWeather(_clock());

  /// Switch the active weather source by string ID (e.g. for onboarding or settings).
  void setSourceId(String sourceId) {
    if (_activeSourceId == sourceId) return;
    _activeSourceId = sourceId;
    _request++;
    _cached = null;
    notifyListeners();
  }

  /// Registers or overrides a source (useful for mocks and tests).
  void registerSource(WeatherSource source) {
    _sources[source.id] = source;
  }

  /// Set cached observation manually (for unit testing or restoring saved state).
  void setCachedObservation(WeatherObservation? obs) {
    _request++;
    _cached = obs;
    notifyListeners();
  }

  /// Fetches fresh observation from the active source.
  Future<WeatherObservation?> refresh({
    required double latitude,
    required double longitude,
  }) async {
    final src = _sources[_activeSourceId];
    if (src == null) return null;

    final location = '$latitude,$longitude';
    if (_location != location) {
      _location = location;
      _cached = null;
      notifyListeners();
    }
    final request = ++_request;
    final obs = await src.fetch(latitude: latitude, longitude: longitude);
    if (_disposed || request != _request) return null;
    if (obs != null) {
      _cached = obs;
      notifyListeners();
    }
    return obs;
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
