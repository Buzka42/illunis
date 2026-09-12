import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:illunis/core/sky/sky_weather.dart';
import 'package:illunis/core/weather/open_meteo_source.dart';
import 'package:illunis/core/weather/weather_model.dart';
import 'package:illunis/core/weather/weather_service.dart';
import 'package:illunis/core/weather/weather_source.dart';

void main() {
  group('WeatherObservation staleness rule', () {
    test('observation is fresh under 3 hours and stale after 3 hours', () {
      final fetchedAt = DateTime(2026, 9, 11, 12, 0);
      const sky = SkyWeather(cloudCoverage: 0.5, rain: 0.0);
      final obs = WeatherObservation(
        observedAt: fetchedAt,
        currentTempC: 20.0,
        precipitationMm: 0.0,
        weatherCode: 2,
        skyWeather: sky,
        hourly24h: const [],
        sourceId: 'test',
      );

      // 2h59m later: fresh
      final freshTime = fetchedAt.add(const Duration(hours: 2, minutes: 59));
      expect(obs.isStale(freshTime), isFalse);
      expect(obs.activeSkyWeather(freshTime), equals(sky));

      // 3h01m later: stale (>3h -> null SkyWeather)
      final staleTime = fetchedAt.add(const Duration(hours: 3, minutes: 1));
      expect(obs.isStale(staleTime), isTrue);
      expect(obs.activeSkyWeather(staleTime), isNull);
    });
  });

  group('OpenMeteoWeatherSource mapping', () {
    test('parses clear, rain, snow, and hourly projections', () async {
      final now = DateTime.now();
      final t0 = '${now.toIso8601String().substring(0, 13)}:00';
      final t1 = '${now.add(const Duration(hours: 1)).toIso8601String().substring(0, 13)}:00';
      final t2 = '${now.add(const Duration(hours: 2)).toIso8601String().substring(0, 13)}:00';

      final mockResponse = jsonEncode({
        'current': {
          'temperature_2m': 18.5,
          'relative_humidity_2m': 75.0,
          'precipitation': 2.4,
          'rain': 2.4,
          'snowfall': 0.0,
          'weather_code': 63, // moderate rain
          'cloud_cover': 80.0,
        },
        'hourly': {
          'time': [t0, t1, t2],
          'temperature_2m': [18.5, 17.0, 16.0],
          'precipitation_probability': [80, 90, 40],
          'weather_code': [63, 65, 3],
          'precipitation': [2.4, 4.0, 0.1],
        },
      });

      final client = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final source = OpenMeteoWeatherSource(client: client);
      final obs = await source.fetch(latitude: 52.23, longitude: 21.01);

      expect(obs, isNotNull);
      expect(obs!.currentTempC, 18.5);
      expect(obs.weatherCode, 63);
      expect(obs.skyWeather, isNotNull);
      expect(obs.skyWeather!.rain, greaterThan(0.0));
      expect(obs.skyWeather!.cloudCoverage, closeTo(0.95, 0.01));
      expect(obs.hourly24h, hasLength(3));
      expect(obs.hourly24h.first.precipitationChance, 0.8);
      expect(obs.hourly24h[1].tempC, 17.0);
    });

    test('maps snow weather codes properly', () async {
      final mockResponse = jsonEncode({
        'current': {
          'temperature_2m': -2.0,
          'relative_humidity_2m': 90.0,
          'precipitation': 1.5,
          'rain': 0.0,
          'snowfall': 1.5,
          'weather_code': 73, // moderate snow
          'cloud_cover': 100.0,
        },
        'hourly': {
          'time': <String>[],
          'temperature_2m': <num>[],
          'precipitation_probability': <num>[],
          'weather_code': <num>[],
          'precipitation': <num>[],
        },
      });

      final client = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final source = OpenMeteoWeatherSource(client: client);
      final obs = await source.fetch(latitude: 52.23, longitude: 21.01);

      expect(obs, isNotNull);
      expect(obs!.skyWeather!.snow, greaterThan(0.0));
      expect(obs.skyWeather!.rain, 0.0);
    });

    test('handles HTTP 500 error fail-closed', () async {
      final client = MockClient((request) async {
        return http.Response('Internal error', 500);
      });

      final source = OpenMeteoWeatherSource(client: client);
      final obs = await source.fetch(latitude: 52.23, longitude: 21.01);

      expect(obs, isNull);
    });
  });

  group('WeatherService caching and switching', () {
    test('notifies listeners and stores cached observation', () async {
      var fetchCount = 0;
      final fakeSource = _FakeWeatherSource(
        onFetch: () {
          fetchCount++;
          return WeatherObservation(
            observedAt: DateTime(2026, 9, 11, 12, 0),
            currentTempC: 22.0,
            precipitationMm: 0.0,
            weatherCode: 1,
            skyWeather: const SkyWeather(cloudCoverage: 0.1),
            hourly24h: const [],
            sourceId: 'fake',
          );
        },
      );

      final service = WeatherService(
        defaultSource: fakeSource,
        clock: () => DateTime(2026, 9, 11, 12, 30),
      );

      var notified = false;
      service.addListener(() => notified = true);

      await service.refresh(latitude: 52.23, longitude: 21.01);
      expect(fetchCount, 1);
      expect(service.cachedObservation, isNotNull);
      expect(service.currentSkyWeather, isNotNull);
      expect(notified, isTrue);
    });

    test('switching source changes active source ID', () async {
      final s1 = _FakeWeatherSource(id: 's1', name: 'Source 1');
      final s2 = _FakeWeatherSource(id: 's2', name: 'Source 2');

      final service = WeatherService(
        defaultSource: s1,
        extraSources: {'s2': s2},
      );

      await service.refresh(latitude: 52.23, longitude: 21.01);
      expect(service.cachedObservation?.sourceId, 's1');

      service.setSourceId('s2');
      expect(service.activeSourceId, 's2');
      await service.refresh(latitude: 52.23, longitude: 21.01);
      expect(service.cachedObservation?.sourceId, 's2');
    });
  });
}

class _FakeWeatherSource implements WeatherSource {
  _FakeWeatherSource({
    this.id = 'fake',
    this.name = 'Fake',
    this.onFetch,
  });

  @override
  final String id;

  @override
  final String name;

  final WeatherObservation Function()? onFetch;

  @override
  Future<WeatherObservation?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    if (onFetch != null) return onFetch!();
    return WeatherObservation(
      observedAt: DateTime.now(),
      currentTempC: 21.0,
      precipitationMm: 0.0,
      weatherCode: 1,
      skyWeather: const SkyWeather(cloudCoverage: 0.2),
      hourly24h: const [],
      sourceId: id,
    );
  }
}
