import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/state/sky_state_source.dart';

double angleError(double a, double b) => ((a - b + 180) % 360 - 180).abs();

void main() {
  test(
    'timeline follows the lunar orbit unless phase is explicitly scrubbed',
    () {
      final epoch = epochDaysForDate(2026, 9, 9);
      final source = SkyState(
        timeOfDay: 0,
        dayOfYear: 252,
        epochDays: epoch,
        latitudeDeg: 52.23,
        moonPhase: moonPhaseAt(epoch),
      );
      final scrubbed = const SkyOverrides(timeOfDay: 0.8).apply(source);
      expect(scrubbed.moonPhase, closeTo(moonPhaseAt(epoch + 0.8), 1e-9));
      expect(
        const SkyOverrides(
          timeOfDay: 0.8,
          moonPhase: 0.5,
        ).apply(source).moonPhase,
        0.5,
      );
    },
  );
  final fixture =
      jsonDecode(
            File(
              'test/sky/fixtures/warsaw_horizons_2026.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final day in fixture['days'] as List<dynamic>) {
    test('Warsaw ${day['date']} agrees with JPL Horizons', () {
      final date = DateTime.parse(day['date'] as String);
      final offset = (day['utcOffsetHours'] as num).toDouble();
      final midnight =
          epochDaysForDate(date.year, date.month, date.day) - offset / 24;
      SkyState at(double t) => SkyState(
        timeOfDay: t,
        dayOfYear: civilDayOfYear(date),
        epochDays: midnight,
        latitudeDeg: 52.23,
        moonPhase: moonPhaseAt(midnight + t),
        solarNoon: solarNoonFor(midnight + t, 21.01, offset),
      );
      var maxSun = 0.0, maxMoon = 0.0, maxIllum = 0.0;
      for (final body in ['sun', 'moon']) {
        final rows = day[body] as List<dynamic>;
        for (var i = 0; i < rows.length; i++) {
          final scene = CelestialScene.resolve(at(i / 8));
          final row = rows[i] as Map<String, dynamic>;
          final direction = body == 'sun' ? scene.sunDir : scene.moonDir;
          final alt =
              (direction.altitude * radToDeg - (row['altitudeDeg'] as num))
                  .abs();
          final az = angleError(
            direction.azimuth * radToDeg,
            (row['azimuthDeg'] as num).toDouble(),
          );
          expect(alt, lessThan(0.5), reason: '$body ${row['utc']} altitude');
          expect(az, lessThan(0.5), reason: '$body ${row['utc']} azimuth');
          if (body == 'sun') {
            maxSun = math.max(maxSun, math.max(alt, az));
          } else {
            maxMoon = math.max(maxMoon, math.max(alt, az));
            final illum =
                (scene.moonIllumination * 100 -
                        (row['illuminatedPercent'] as num))
                    .abs();
            maxIllum = math.max(maxIllum, illum);
            expect(
              illum,
              lessThan(1.0),
              reason: 'Illumination percentage points',
            );
          }
        }
      }
      final scene = CelestialScene.resolve(at(0.5));
      final events = day['eventsLocalMinutes'] as Map<String, dynamic>;
      final riseError = (scene.sunrise! * 1440 - (events['sunrise'] as num))
          .abs();
      final setError = (scene.sunset! * 1440 - (events['sunset'] as num)).abs();
      expect(riseError, lessThan(2));
      expect(setError, lessThan(2));
      // ignore: avoid_print -- captured verification evidence for the handoff.
      print(
        'EPHEMERIS ${day['date']}: sunMax=${maxSun.toStringAsFixed(4)}deg '
        'moonMax=${maxMoon.toStringAsFixed(4)}deg illuminationMax=${maxIllum.toStringAsFixed(4)}pp '
        'sunriseError=${riseError.toStringAsFixed(3)}min sunsetError=${setError.toStringAsFixed(3)}min '
        'sunrise=${formatHours(scene.sunrise!)} sunset=${formatHours(scene.sunset!)}',
      );
    });
  }
  test(
    'civil clock preserves UTC and day number without DST duration arithmetic',
    () {
      final utc = DateTime.utc(2026, 9, 9, 10, 30);
      expect(civilDayFraction(utc), 10.5 / 24);
      expect(civilDayOfYear(utc), 252);
      expect(
        civilMidnightEpoch(utc) + civilDayFraction(utc),
        closeTo(
          utc.difference(DateTime.utc(2000, 1, 1, 12)).inSeconds / 86400,
          1e-9,
        ),
      );
      expect(
        equationOfTimeMinutes(epochDaysForDate(2026, 11, 3)),
        greaterThan(16),
      );
      expect(solarNoonFor(epochDaysForDate(2026, 11, 3), 0, 0), lessThan(0.5));
    },
  );
}
