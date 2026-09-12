import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:illunis/core/weather/open_meteo_source.dart';
import 'package:illunis/core/weather/weather_model.dart';
import 'package:illunis/core/weather/weather_service.dart';
import 'package:illunis/core/weather/weather_source.dart';
import 'package:illunis/features/timeline/weather_projection.dart';

void main() {
  test(
    'epoch forecast times are instants, missing temperature is not zero',
    () async {
      final now = DateTime.utc(2026, 9, 12, 12);
      final client = MockClient((request) async {
        expect(request.url.queryParameters['timeformat'], 'unixtime');
        return http.Response(
          jsonEncode({
            'current': {
              'temperature_2m': 17,
              'time': now.millisecondsSinceEpoch ~/ 1000,
            },
            'hourly': {
              'time': [
                now.millisecondsSinceEpoch ~/ 1000,
                now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                    1000,
              ],
              'temperature_2m': [17, null],
              'precipitation_probability': [50, 80],
              'precipitation': [1, 2],
              'weather_code': [63, 99],
            },
          }),
          200,
        );
      });
      final source = OpenMeteoWeatherSource(client: client, clock: () => now);
      final result = await source.fetch(latitude: 52.23, longitude: 21.01);
      expect(result!.hourly24h, hasLength(1));
      expect(result.hourly24h.single.time.toUtc(), now);
      expect(result.observedAt.toUtc(), now);
      expect(result.hourly24h.single.precipitationChance, 0.5);
      final absent = OpenMeteoWeatherSource(
        client: MockClient((_) async => http.Response('{"current":{}}', 200)),
      );
      expect(await absent.fetch(latitude: 0, longitude: 0), isNull);
    },
  );

  test(
    'rain, snow and hail require intensity and probability and use civil dates',
    () {
      final day = DateTime(2026, 9, 12);
      final observation = WeatherObservation(
        observedAt: day,
        currentTempC: 10,
        hourly24h: [
          for (final code in [63, 75, 99])
            HourlyWeatherProjection(
              time: day.add(const Duration(hours: 12)),
              tempC: 10,
              weatherCode: code,
              precipitationMm: 2,
              precipitationChance: 0.5,
            ),
          HourlyWeatherProjection(
            time: day,
            tempC: 10,
            weatherCode: 63,
            precipitationMm: 2,
          ),
          HourlyWeatherProjection(
            time: day,
            tempC: 10,
            weatherCode: 63,
            precipitationMm: 2,
            precipitationChance: 0,
          ),
          HourlyWeatherProjection(
            time: DateTime(2026, 9, 13),
            tempC: 10,
            weatherCode: 63,
            precipitationMm: 2,
            precipitationChance: 1,
          ),
        ],
      );
      final marks = precipitationMarks(observation, day);
      expect(marks.map((m) => m.kind), [
        PrecipitationKind.rain,
        PrecipitationKind.snow,
        PrecipitationKind.hail,
      ]);
      expect(marks.every((m) => m.weight == 0.25 && m.time == 0.5), isTrue);
      expect(precipitationMarks(null, day), isEmpty);
    },
  );

  test(
    'turning weather off rejects an in-flight result and never falls back',
    () async {
      final source = _DelayedSource();
      final service = WeatherService(defaultSource: source);
      final request = service.refresh(latitude: 52, longitude: 21);
      service.setSourceId('off');
      source.result.complete(
        WeatherObservation(observedAt: DateTime.now(), currentTempC: 20),
      );
      expect(await request, isNull);
      expect(service.cachedObservation, isNull);
      expect(await service.refresh(latitude: 52, longitude: 21), isNull);
      expect(source.calls, 1);
      service.dispose();
    },
  );
}

class _DelayedSource implements WeatherSource {
  final result = Completer<WeatherObservation?>();
  int calls = 0;
  @override
  String get id => 'test';
  @override
  String get name => 'Test';
  @override
  Future<WeatherObservation?> fetch({
    required double latitude,
    required double longitude,
  }) {
    calls++;
    return result.future;
  }
}
