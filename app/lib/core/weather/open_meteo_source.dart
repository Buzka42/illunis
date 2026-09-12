import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sky/sky_weather.dart';
import 'weather_model.dart';
import 'weather_source.dart';

/// Open-Meteo weather fetcher. Requires no API keys.
class OpenMeteoWeatherSource implements WeatherSource {
  OpenMeteoWeatherSource({this.client, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;

  final http.Client? client;

  @override
  String get id => 'open-meteo';

  @override
  String get name => 'Open-Meteo';

  @override
  Future<WeatherObservation?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final httpClient = client ?? http.Client();
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=$latitude&longitude=$longitude&'
      'current=temperature_2m,relative_humidity_2m,precipitation,rain,snowfall,weather_code,cloud_cover&'
      'hourly=temperature_2m,precipitation_probability,weather_code,precipitation&'
      'forecast_days=2&timeformat=unixtime',
    );

    try {
      final res = await httpClient
          .get(url)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final data = jsonDecode(res.body);
      if (data is! Map) return null;

      final current = data['current'];
      if (current is! Map) return null;

      final currentTemp = (current['temperature_2m'] as num?)?.toDouble();
      if (currentTemp == null || !currentTemp.isFinite) return null;
      final precipMm = (current['precipitation'] as num?)?.toDouble();
      final rainMm = (current['rain'] as num?)?.toDouble() ?? 0.0;
      final snowMm = (current['snowfall'] as num?)?.toDouble() ?? 0.0;
      final cloudPct = (current['cloud_cover'] as num?)?.toDouble() ?? 0.0;
      final code = (current['weather_code'] as num?)?.toInt();

      final skyWeather = _normalizeSkyWeather(
        code: code,
        cloudPercent: cloudPct,
        rainMm: rainMm,
        snowMm: snowMm,
      );

      final hourly = <HourlyWeatherProjection>[];
      double? minTemp;
      double? maxTemp;
      double? currentPrecipChance;

      final hourlyData = data['hourly'];
      if (hourlyData is Map) {
        final times = hourlyData['time'] as List?;
        final temps = hourlyData['temperature_2m'] as List?;
        final probs = hourlyData['precipitation_probability'] as List?;
        final precips = hourlyData['precipitation'] as List?;
        final codes = hourlyData['weather_code'] as List?;

        if (times != null && temps != null) {
          final now = _clock();
          var count = 0;
          for (
            var i = 0;
            i < times.length && i < temps.length && count < 24;
            i++
          ) {
            final t = _timestamp(times[i]);
            if (t == null) continue;
            // Only upcoming or current hours
            if (t.isBefore(now.subtract(const Duration(minutes: 59)))) continue;

            final temp = (temps[i] as num?)?.toDouble();
            if (temp == null || !temp.isFinite) continue;
            final prob = probs != null && i < probs.length
                ? (probs[i] as num?)?.toDouble()
                : null;
            final pMm = precips != null && i < precips.length
                ? (precips[i] as num?)?.toDouble()
                : null;
            final wCode = codes != null && i < codes.length
                ? (codes[i] as num?)?.toInt()
                : null;

            if (minTemp == null || temp < minTemp) minTemp = temp;
            if (maxTemp == null || temp > maxTemp) maxTemp = temp;
            if (count == 0 && prob != null) {
              currentPrecipChance = prob / 100.0;
            }

            hourly.add(
              HourlyWeatherProjection(
                time: t,
                tempC: temp,
                precipitationChance: prob != null ? prob / 100.0 : null,
                precipitationMm: pMm,
                weatherCode: wCode,
              ),
            );
            count++;
          }
        }
      }

      return WeatherObservation(
        observedAt: _timestamp(current['time']) ?? _clock(),
        currentTempC: currentTemp,
        minTempC: minTemp,
        maxTempC: maxTemp,
        precipitationChance: currentPrecipChance,
        precipitationMm: precipMm,
        weatherCode: code,
        skyWeather: skyWeather,
        hourly24h: hourly,
        sourceId: id,
      );
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  // Request GMT epoch seconds; display on the device civil clock. ISO input
  // remains accepted for stored/test responses, interpreted as GMT if unzoned.
  static DateTime? _timestamp(Object? value) {
    if (value is num && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) {
      final zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
      return DateTime.tryParse(zoned ? value : '${value}Z')?.toLocal();
    }
    return null;
  }

  /// Maps WMO weather code + current metrics into normalized SkyWeather components.
  static SkyWeather _normalizeSkyWeather({
    int? code,
    double cloudPercent = 0.0,
    double rainMm = 0.0,
    double snowMm = 0.0,
  }) {
    var cloud = (cloudPercent / 100.0).clamp(0.0, 1.0);
    var cumulus = 0.5;
    var cirrus = 0.0;
    var rain = 0.0;
    var fog = 0.0;
    var snow = 0.0;

    if (code != null) {
      switch (code) {
        case 0: // Clear
          cloud = 0.0;
          break;
        case 1: // Mainly clear
          cloud = cloud == 0 ? 0.2 : cloud;
          cumulus = 0.5;
          break;
        case 2: // Partly cloudy
          cloud = cloud == 0 ? 0.5 : cloud;
          cumulus = 0.6;
          break;
        case 3: // Overcast
          cloud = 0.95;
          cumulus = 0.2;
          cirrus = 0.1;
          break;
        case 45: // Fog
        case 48: // Depositing rime fog
          fog = 0.8;
          cloud = cloud < 0.6 ? 0.6 : cloud;
          break;
        case 51: // Drizzle light
        case 53: // Drizzle moderate
        case 55: // Drizzle dense
          cloud = 0.8;
          rain = (code - 49) * 0.12;
          break;
        case 56: // Freezing drizzle light
        case 57: // Freezing drizzle dense
          cloud = 0.85;
          rain = 0.2;
          snow = 0.2;
          break;
        case 61: // Rain slight
          cloud = 0.85;
          rain = 0.35;
          break;
        case 63: // Rain moderate
          cloud = 0.95;
          rain = 0.65;
          break;
        case 65: // Rain heavy
          cloud = 1.0;
          rain = 0.95;
          break;
        case 66: // Freezing rain light
        case 67: // Freezing rain heavy
          cloud = 0.95;
          rain = 0.5;
          snow = 0.3;
          break;
        case 71: // Snow slight
          cloud = 0.85;
          snow = 0.35;
          break;
        case 73: // Snow moderate
          cloud = 0.95;
          snow = 0.65;
          break;
        case 75: // Snow heavy
          cloud = 1.0;
          snow = 0.95;
          break;
        case 77: // Snow grains
          cloud = 0.9;
          snow = 0.4;
          break;
        case 80: // Rain showers slight
        case 81: // Rain showers moderate
        case 82: // Rain showers violent
          cloud = 0.8;
          cumulus = 0.85;
          rain = (code - 79) * 0.3;
          break;
        case 85: // Snow showers slight
        case 86: // Snow showers heavy
          cloud = 0.85;
          cumulus = 0.85;
          snow = (code - 84) * 0.45;
          break;
        case 95: // Thunderstorm
          cloud = 1.0;
          cumulus = 0.9;
          rain = 0.8;
          break;
        case 96: // Thunderstorm with hail slight
        case 99: // Thunderstorm with hail heavy
          cloud = 1.0;
          cumulus = 0.95;
          rain = 0.9;
          snow = 0.4;
          break;
      }
    }

    if (rainMm > 0 && rain == 0) {
      rain = (rainMm / 5.0).clamp(0.1, 1.0);
      if (cloud < 0.7) cloud = 0.7;
    }
    if (snowMm > 0 && snow == 0) {
      snow = (snowMm / 5.0).clamp(0.1, 1.0);
      if (cloud < 0.7) cloud = 0.7;
    }

    return SkyWeather(
      cloudCoverage: cloud.clamp(0.0, 1.0),
      cumulus: cumulus.clamp(0.0, 1.0),
      cirrus: cirrus.clamp(0.0, 1.0),
      rain: rain.clamp(0.0, 1.0),
      fog: fog.clamp(0.0, 1.0),
      snow: snow.clamp(0.0, 1.0),
    );
  }
}
