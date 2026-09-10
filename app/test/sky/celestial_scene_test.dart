import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_camera.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/sky/star_catalog.dart';
import 'package:illunis/core/sky/star_field.dart';

SkyState _state({
  double t = 0.5,
  double day = 80,
  double lat = 0,
  double moon = 0.5,
  double solarNoon = 0.5,
}) => SkyState(
  timeOfDay: t,
  dayOfYear: day,
  // 2026 is not a leap year; day 80 is 21 March, the equinox.
  epochDays: epochDaysForDate(2026, 1, 1) + (day - 1),
  latitudeDeg: lat,
  moonPhase: moon,
  solarNoon: solarNoon,
);

double _bearingDelta(double a, double b) {
  final d = wrapAngle(a - b);
  return d > math.pi ? 2 * math.pi - d : d;
}

void main() {
  group('ephemeris', () {
    test('epoch days match J2000 and a known JD', () {
      expect(epochDaysForDate(2000, 1, 1), closeTo(-0.5, 1e-9));
      // 2026-09-06 00:00 UT is JD 2461289.5.
      expect(
        epochDaysForDate(2026, 9, 6),
        closeTo(2461289.5 - 2451545.0, 1e-9),
      );
    });

    test('the Sun crosses the equator at the March equinox', () {
      final lon = sunEclipticLongitude(epochDaysForDate(2026, 3, 20) + 0.6);
      expect(lon * radToDeg, anyOf(lessThan(1.0), greaterThan(359.0)));
    });

    test('inner planets keep to their maximum elongation', () {
      for (var d = 0; d < 3000; d += 37) {
        final e = epochDaysForDate(2020, 1, 1) + d;
        final v = planetEquatorial(Planet.venus, e).elongationRad * radToDeg;
        final m = planetEquatorial(Planet.mercury, e).elongationRad * radToDeg;
        expect(v, lessThan(48.5), reason: 'venus day $d');
        expect(m, lessThan(28.5), reason: 'mercury day $d');
      }
    });

    test('planets resolve to unit directions and sensible magnitudes', () {
      final s = CelestialScene.resolve(_state(t: 0.0, lat: 52, day: 249));
      expect(s.planets.length, 5);
      for (final p in s.planets) {
        expect(p.dir.length, closeTo(1, 1e-9));
        expect(p.magnitude, inInclusiveRange(-5, 3));
        expect(p.visibility, inInclusiveRange(0, 1));
      }
      final venus = s.planets[Planet.venus.index];
      expect(
        venus.brightness,
        greaterThan(s.planets[Planet.saturn.index].brightness),
      );
    });

    test('a planet below the horizon or in daylight is not visible', () {
      final noon = CelestialScene.resolve(_state(t: 0.5, lat: 52, day: 249));
      for (final p in noon.planets) {
        expect(p.visibility, lessThan(1e-6));
      }
    });
  });

  group('sun', () {
    test('is at the zenith at noon on the equinox at the equator', () {
      final s = CelestialScene.resolve(_state());
      expect(s.sunAltitudeRad * radToDeg, closeTo(90, 1.0));
    });

    test('is below the horizon at midnight in the temperate zone', () {
      final s = CelestialScene.resolve(_state(t: 0, lat: 52));
      expect(s.sunAltitudeRad, lessThan(-0.5));
    });

    test('rises in the east and sets in the west', () {
      final s = CelestialScene.resolve(_state(lat: 52, day: 172));
      final rise = s.sunDirectionAt(s.sunrise!);
      final set = s.sunDirectionAt(s.sunset!);
      expect(rise.altitude.abs() * radToDeg, lessThan(1.0));
      expect(set.altitude.abs() * radToDeg, lessThan(1.0));
      expect(rise.azimuth * radToDeg, inInclusiveRange(30, 90));
      expect(set.azimuth * radToDeg, inInclusiveRange(270, 330));
    });

    test('summer day is long, winter day is short at 52°N', () {
      final summer = CelestialScene.resolve(_state(lat: 52, day: 172));
      final winter = CelestialScene.resolve(_state(lat: 52, day: 355));
      expect(summer.dayLength! * 24, inInclusiveRange(16, 17.2));
      expect(winter.dayLength! * 24, inInclusiveRange(7.4, 8.4));
    });

    test('never sets at 80°N in June', () {
      final s = CelestialScene.resolve(_state(lat: 80, day: 172));
      expect(s.sunrise, isNull);
      expect(s.sunset, isNull);
      expect(s.sunDirectionAt(0).altitude, greaterThan(0));
    });
  });

  group('moon', () {
    test('is full opposite the sun', () {
      final s = CelestialScene.resolve(_state(t: 0.0, lat: 52, moon: 0.5));
      // Orbital latitude and topocentric parallax prevent exact opposition.
      expect(s.moonIllumination, greaterThan(0.995));
      expect(s.sunDir.dot(s.moonDir), lessThan(-0.7));
    });

    test('new moon travels with the sun', () {
      final s = CelestialScene.resolve(_state(t: 0.5, lat: 52, moon: 0.0));
      expect(s.moonIllumination, lessThan(0.005));
      expect(s.sunDir.dot(s.moonDir), greaterThan(0.95));
    });

    test('phase from date is in range and advances', () {
      final a = moonPhaseFor(DateTime.utc(2026, 9, 6));
      final b = moonPhaseFor(DateTime.utc(2026, 9, 13));
      expect(a, inInclusiveRange(0, 1));
      // Eccentricity makes the weekly advance nonuniform; accuracy is
      // checked independently in ephemeris_reference_test.dart.
      expect(((b - a) % 1.0), inInclusiveRange(0.20, 0.28));
    });
  });

  group('stars', () {
    test('sidereal time advances with the clock', () {
      final a = CelestialScene.resolve(_state(t: 0.5, lat: 52));
      final b = CelestialScene.resolve(_state(t: 0.6, lat: 52));
      final d = wrapAngle(b.siderealRad - a.siderealRad);
      // A sidereal day is shorter than a solar one by one part in 365.25.
      expect(d, closeTo(0.1 * 2 * math.pi * 366.25 / 365.25, 5e-4));
    });

    test('Sirius is the brightest catalog star', () {
      expect(kStarCount, greaterThan(4000));
      expect(kStarNameIndex['Sirius'], 0);
      expect(catalogStarAt(0).vMag, closeTo(-1.44, 0.05));
      expect(catalogStarAt(0).vMag, lessThan(catalogStarAt(1).vMag));
    });

    test('Polaris sits on the north celestial pole', () {
      final polaris = catalogStarByName('Polaris')!;
      expect(polaris.decRad * radToDeg, closeTo(89.26, 1.0));
      final scene = CelestialScene.resolve(_state(t: 0.5, day: 6, lat: 52.23));
      final dir = catalogStarDirection(
        polaris,
        scene.siderealRad,
        scene.latitudeRad,
      );
      expect(dir.altitude * radToDeg, closeTo(52.23, 1.5));
      final az = dir.azimuth * radToDeg;
      expect(az < 20 || az > 340, isTrue, reason: 'az $az');
    });

    test('Orion\'s belt is up on a January evening at 52°N, not in June', () {
      const belt = ['Alnitak', 'Alnilam', 'Mintaka'];
      final winter = CelestialScene.resolve(
        _state(t: 21 / 24, day: 6, lat: 52.23, solarNoon: 0.48),
      );
      for (final name in belt) {
        final star = catalogStarByName(name)!;
        final dir = catalogStarDirection(
          star,
          winter.siderealRad,
          winter.latitudeRad,
        );
        expect(dir.altitude, greaterThan(0.05), reason: '$name winter');
      }
      final summer = CelestialScene.resolve(
        _state(t: 23 / 24, day: 172, lat: 52.23, solarNoon: 0.48),
      );
      for (final name in belt) {
        final star = catalogStarByName(name)!;
        final dir = catalogStarDirection(
          star,
          summer.siderealRad,
          summer.latitudeRad,
        );
        expect(dir.altitude, lessThan(0), reason: '$name summer');
      }
    });

    test('catalog stars above the horizon project into the sky half', () {
      final scene = CelestialScene.resolve(
        _state(t: 21 / 24, day: 6, lat: 52.23, solarNoon: 0.48),
      );
      final cam = SkyCamera(size: const Size(390, 844), azimuthRad: math.pi);
      var seen = 0;
      for (var i = 0; i < kStarCount; i++) {
        final star = catalogStarAt(i);
        final dir = catalogStarDirection(
          star,
          scene.siderealRad,
          scene.latitudeRad,
        );
        if (dir.y < 0) continue;
        final p = cam.project(dir);
        if (p == null || !cam.contains(p)) continue;
        expect(p.dy, lessThanOrEqualTo(cam.principal.dy + 1.0));
        seen++;
      }
      expect(seen, greaterThan(50));
    });
  });

  group('camera', () {
    test('project and unproject round-trip', () {
      final cam = SkyCamera(size: const Size(390, 844), azimuthRad: 3.0);
      for (final alt in [-10.0, 0.0, 20.0, 45.0, 70.0]) {
        for (final dAz in [-25.0, 0.0, 25.0]) {
          final d = directionFromAltAz(alt * degToRad, 3.0 + dAz * degToRad);
          final p = cam.project(d)!;
          final back = cam.unproject(p);
          expect(back.dot(d), closeTo(1, 1e-9), reason: 'alt $alt dAz $dAz');
        }
      }
    });

    test('horizon is a straight line at the principal point', () {
      final cam = SkyCamera(size: const Size(390, 844), azimuthRad: 1.0);
      for (final dAz in [-30.0, -10.0, 10.0, 30.0]) {
        final p = cam.project(directionFromAltAz(0, 1.0 + dAz * degToRad))!;
        expect(p.dy, closeTo(cam.principal.dy, 1e-9));
      }
    });

    test('noon at 52°N still faces the sun', () {
      final scene = CelestialScene.resolve(_state(t: 0.5, lat: 52, day: 80));
      expect(
        _bearingDelta(scene.trackAzimuthRad, scene.sunDir.azimuth),
        lessThan(0.2),
      );
    });

    test('a new-moon night looks south so Orion is in the window', () {
      final scene = CelestialScene.resolve(
        _state(t: 21 / 24, day: 6, lat: 52.23, solarNoon: 0.48, moon: 0),
      );
      expect(scene.sunDir.altitude, lessThan(0));
      expect(
        _bearingDelta(scene.trackAzimuthRad, math.pi),
        lessThan(25 * degToRad),
      );
      final cam = SkyCamera(
        size: const Size(390, 844),
        azimuthRad: scene.trackAzimuthRad,
      );
      final mintaka = catalogStarByName('Mintaka')!;
      final dir = catalogStarDirection(
        mintaka,
        scene.siderealRad,
        scene.latitudeRad,
      );
      expect(dir.altitude, greaterThan(0.05));
      final p = cam.project(dir);
      expect(p, isNotNull);
      expect(cam.contains(p!), isTrue);
    });

    test('a risen full moon takes the night camera', () {
      final scene = CelestialScene.resolve(
        _state(t: 21 / 24, day: 6, lat: 52.23, solarNoon: 0.48, moon: 0.5),
      );
      expect(scene.moonDir.altitude, greaterThan(0.05));
      final toMoon = _bearingDelta(
        scene.trackAzimuthRad,
        scene.moonDir.azimuth,
      );
      final toSouth = _bearingDelta(scene.trackAzimuthRad, math.pi);
      expect(toMoon, lessThan(toSouth));
      expect(toMoon, lessThan(0.6));
    });
  });

  group('state', () {
    test('lerp takes the short way round midnight', () {
      final a = _state(t: 0.98);
      final b = _state(t: 0.02);
      final m = SkyState.lerp(a, b, 0.5);
      expect(m.timeOfDay, closeTo(0.0, 1e-9));
    });

    test('a null vital snaps instead of fading through a number', () {
      final a = _state().copyWith(recovery: null);
      final b = _state().copyWith(recovery: 0.8);
      expect(SkyState.lerp(a, b, 0.5).recovery, 0.8);
      expect(SkyState.lerp(b, a, 0.5).recovery, isNull);
      expect(SkyState.lerp(a, b, 1.0).recovery, 0.8);
    });

    test('absent vitals leave the atmosphere neutral', () {
      final none = CelestialScene.resolve(_state(lat: 52));
      expect(none.turbidity, inInclusiveRange(2.5, 4.0));
      expect(none.stillness, inInclusiveRange(0.7, 0.9));
    });
  });
}
