import 'package:flutter/foundation.dart';

import '../sky/sky_weather.dart';

/// Hourly projection point for the 24-hour forecast strip.
@immutable
class HourlyWeatherProjection {
  const HourlyWeatherProjection({
    required this.time,
    required this.tempC,
    this.precipitationChance,
    this.precipitationMm,
    this.weatherCode,
  });

  final DateTime time;
  final double tempC;
  final double? precipitationChance;
  final double? precipitationMm;
  final int? weatherCode;

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'tempC': tempC,
    'precipitationChance': precipitationChance,
    'precipitationMm': precipitationMm,
    'weatherCode': weatherCode,
  };

  factory HourlyWeatherProjection.fromJson(Map<String, Object?> j) =>
      HourlyWeatherProjection(
        time: DateTime.parse(j['time'] as String),
        tempC: (j['tempC'] as num).toDouble(),
        precipitationChance: (j['precipitationChance'] as num?)?.toDouble(),
        precipitationMm: (j['precipitationMm'] as num?)?.toDouble(),
        weatherCode: (j['weatherCode'] as num?)?.toInt(),
      );
}

/// A weather observation captured from an external meteorological source.
/// Follows the instrument honesty rules:
/// - Stale after 3 hours (> 3 h -> null activeSkyWeather)
/// - Unobserved components are null
@immutable
class WeatherObservation {
  const WeatherObservation({
    required this.observedAt,
    required this.currentTempC,
    this.minTempC,
    this.maxTempC,
    this.precipitationChance,
    this.precipitationMm,
    this.weatherCode,
    this.skyWeather,
    this.hourly24h = const [],
    this.sourceId = 'open-meteo',
  });

  final DateTime observedAt;
  final double currentTempC;
  final double? minTempC;
  final double? maxTempC;
  final double? precipitationChance;
  final double? precipitationMm;
  final int? weatherCode;
  final SkyWeather? skyWeather;
  final List<HourlyWeatherProjection> hourly24h;
  final String sourceId;

  /// Staleness rule: observations older than 3 hours are stale and null back
  /// to absence on the sky.
  bool isStale(DateTime now) =>
      now.difference(observedAt).abs() > const Duration(hours: 3);

  /// Active SkyWeather component: returns null when observation is stale (>3h),
  /// falling back to the clear-looking unobserved sky.
  SkyWeather? activeSkyWeather(DateTime now) =>
      isStale(now) ? null : skyWeather;

  Map<String, Object?> toJson() => {
    'observedAt': observedAt.toIso8601String(),
    'currentTempC': currentTempC,
    'minTempC': minTempC,
    'maxTempC': maxTempC,
    'precipitationChance': precipitationChance,
    'precipitationMm': precipitationMm,
    'weatherCode': weatherCode,
    'sourceId': sourceId,
    if (skyWeather != null)
      'skyWeather': {
        'cloudCoverage': skyWeather!.cloudCoverage,
        'cumulus': skyWeather!.cumulus,
        'cirrus': skyWeather!.cirrus,
        'rain': skyWeather!.rain,
        'fog': skyWeather!.fog,
        'snow': skyWeather!.snow,
      },
    'hourly24h': hourly24h.map((h) => h.toJson()).toList(),
  };

  factory WeatherObservation.fromJson(Map<String, Object?> j) {
    SkyWeather? weather;
    if (j['skyWeather'] is Map) {
      final sw = (j['skyWeather'] as Map).cast<String, Object?>();
      weather = SkyWeather(
        cloudCoverage: (sw['cloudCoverage'] as num?)?.toDouble() ?? 0.0,
        cumulus: (sw['cumulus'] as num?)?.toDouble() ?? 0.5,
        cirrus: (sw['cirrus'] as num?)?.toDouble() ?? 0.0,
        rain: (sw['rain'] as num?)?.toDouble() ?? 0.0,
        fog: (sw['fog'] as num?)?.toDouble() ?? 0.0,
        snow: (sw['snow'] as num?)?.toDouble() ?? 0.0,
      );
    }
    final hourly = <HourlyWeatherProjection>[];
    if (j['hourly24h'] is List) {
      for (final h in j['hourly24h'] as List) {
        if (h is Map) {
          hourly.add(
            HourlyWeatherProjection.fromJson(h.cast<String, Object?>()),
          );
        }
      }
    }
    return WeatherObservation(
      observedAt: DateTime.parse(j['observedAt'] as String),
      currentTempC: (j['currentTempC'] as num).toDouble(),
      minTempC: (j['minTempC'] as num?)?.toDouble(),
      maxTempC: (j['maxTempC'] as num?)?.toDouble(),
      precipitationChance: (j['precipitationChance'] as num?)?.toDouble(),
      precipitationMm: (j['precipitationMm'] as num?)?.toDouble(),
      weatherCode: (j['weatherCode'] as num?)?.toInt(),
      skyWeather: weather,
      hourly24h: hourly,
      sourceId: j['sourceId'] as String? ?? 'open-meteo',
    );
  }
}
