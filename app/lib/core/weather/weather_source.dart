import 'weather_model.dart';

/// Contract for meteorological observation sources.
/// Weather fetchers are source-agnostic; default is Open-Meteo.
abstract class WeatherSource {
  String get id;
  String get name;

  Future<WeatherObservation?> fetch({
    required double latitude,
    required double longitude,
  });
}
