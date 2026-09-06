import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'celestial_math.dart';
import 'sky_state.dart';

/// Pure geometry and atmosphere parameters resolved from a [SkyState].
///
/// No widgets, no clock, no paint. Everything here is unit-testable and is
/// the single source of truth for both the shader (through uniforms) and the
/// Dart overlay (through [sunDirectionAt] and friends), so the drawn sun and
/// the annotated sun are always the same sun.
@immutable
class ResolvedScene {
  const ResolvedScene({
    required this.state,
    required this.sunDir,
    required this.moonDir,
    required this.siderealRad,
    required this.latitudeRad,
    required this.sunDeclinationRad,
    required this.moonDeclinationRad,
    required this.moonHourAngleOffsetRad,
    required this.moonIllumination,
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.moonset,
    required this.turbidity,
    required this.mieScale,
    required this.exposure,
    required this.stillness,
    required this.trackAzimuthRad,
    required this.planets,
  });

  /// The five naked-eye planets, in [Planet] order.
  final List<PlanetPosition> planets;

  final SkyState state;

  /// Unit direction to the sun, horizontal frame.
  final Vec3 sunDir;

  /// Unit direction to the moon, horizontal frame.
  final Vec3 moonDir;

  /// Local sidereal time, radians. Rotates the star field.
  final double siderealRad;

  final double latitudeRad;
  final double sunDeclinationRad;
  final double moonDeclinationRad;

  /// `H_moon = H_sun + offset`; lets the overlay trace the moon's path.
  final double moonHourAngleOffsetRad;

  /// `0..1`, fraction of the disc lit.
  final double moonIllumination;

  /// Day fractions, null when the body never crosses the horizon today.
  final double? sunrise, sunset, moonrise, moonset;

  /// Atmospheric haze, `~2` crisp to `~8` murky.
  final double turbidity;

  /// Multiplier on aerosol scattering; warmth of the low sky.
  final double mieScale;

  /// Tone-mapping exposure, already adapted for the sun's altitude.
  final double exposure;

  /// `0..1` — `1` is a perfectly still night (no grain breath, slow twinkle).
  final double stillness;

  /// Where the camera looks by default: the brightest thing worth looking at.
  final double trackAzimuthRad;

  double get sunAltitudeRad => sunDir.altitude;
  double get sunAzimuthRad => sunDir.azimuth;
  double get moonAltitudeRad => moonDir.altitude;
  double get moonAzimuthRad => moonDir.azimuth;

  double? get dayLength {
    if (sunrise == null || sunset == null) return null;
    var d = sunset! - sunrise!;
    if (d < 0) d += 1;
    return d;
  }

  /// `0` full night, `1` full day; the sun's altitude on a perceptual ramp.
  double get dayness {
    final a = sunAltitudeRad * radToDeg;
    return smoothstep(-12, 4, a);
  }

  /// Sun direction at another time of the same day, for path drawing.
  Vec3 sunDirectionAt(double timeOfDay) {
    return horizontalDirection(
      sunDeclinationRad,
      solarHourAngle(timeOfDay, state.solarNoon),
      latitudeRad,
    );
  }

  Vec3 moonDirectionAt(double timeOfDay) {
    return horizontalDirection(
      moonDeclinationRad,
      solarHourAngle(timeOfDay, state.solarNoon) + moonHourAngleOffsetRad,
      latitudeRad,
    );
  }

  String describeMoonPhase() {
    final p = state.moonPhase;
    if (p < 0.02 || p > 0.98) return 'New moon';
    if (p < 0.23) return 'Waxing crescent';
    if (p < 0.27) return 'First quarter';
    if (p < 0.48) return 'Waxing gibbous';
    if (p < 0.52) return 'Full moon';
    if (p < 0.73) return 'Waning gibbous';
    if (p < 0.77) return 'Last quarter';
    return 'Waning crescent';
  }

  String describeTwilight() {
    final a = sunAltitudeRad * radToDeg;
    if (a >= 0) return 'Daylight';
    if (a >= -6) return 'Civil twilight';
    if (a >= -12) return 'Nautical twilight';
    if (a >= -18) return 'Astronomical twilight';
    return 'Night';
  }
}

@immutable
class PlanetPosition {
  const PlanetPosition({
    required this.planet,
    required this.dir,
    required this.magnitude,
    required this.elongationRad,
    required this.visibility,
    required this.brightness,
  });

  final Planet planet;
  final Vec3 dir;
  final double magnitude;
  final double elongationRad;

  /// `0..1`: above the horizon and the sky dark enough to show it.
  final double visibility;

  /// `0..1` point intensity for the shader.
  final double brightness;
}

class CelestialScene {
  const CelestialScene._();

  static ResolvedScene resolve(SkyState s) {
    final lat = s.latitudeDeg * degToRad;
    final epoch = s.epochDays + s.timeOfDay;
    // The Sun from the same element set as the planets, so they agree.
    final lambdaSun = sunEclipticLongitude(epoch);
    final eqSun = equatorialFromEcliptic(lambdaSun);
    final dec = eqSun.dec;
    final hSun = solarHourAngle(s.timeOfDay, s.solarNoon);
    final sunDir = horizontalDirection(dec, hSun, lat);

    // The moon sits on the ecliptic, `phase` of a turn ahead of the sun.
    final lambdaMoon = lambdaSun + s.moonPhase * 2 * math.pi;
    final eqMoon = equatorialFromEcliptic(lambdaMoon);
    // Local sidereal time θ = H_sun + α_sun, and H_moon = θ − α_moon.
    final sidereal = wrapAngle(hSun + eqSun.ra);
    final moonOffset = eqSun.ra - eqMoon.ra;
    final moonDir = horizontalDirection(eqMoon.dec, hSun + moonOffset, lat);
    final illum = moonIlluminatedFraction(s.moonPhase);

    final sunAltDeg = sunDir.altitude * radToDeg;
    final planets = <PlanetPosition>[
      for (final p in Planet.values) _planet(p, epoch, sidereal, lat, sunAltDeg),
    ];

    final h0 = hourAngleAtAltitude(dec, lat, riseSetAltitudeRad);
    final sunrise = h0 == null ? null : _frac(s.solarNoon - h0 / (2 * math.pi));
    final sunset = h0 == null ? null : _frac(s.solarNoon + h0 / (2 * math.pi));
    final hm = hourAngleAtAltitude(eqMoon.dec, lat, riseSetAltitudeRad);
    final moonNoon = s.solarNoon - moonOffset / (2 * math.pi);
    final moonrise = hm == null ? null : _frac(moonNoon - hm / (2 * math.pi));
    final moonset = hm == null ? null : _frac(moonNoon + hm / (2 * math.pi));

    // Vitals reach the atmosphere lightly. Recovery is how far you can see;
    // strain warms the low sky; sleep decides how still the night is.
    final recovery = s.recovery ?? 0.75;
    final strain = s.strain ?? 0.2;
    final sleep = s.sleepScore ?? 0.75;
    final turbidity = 1.6 + (1 - recovery) * 4.0;
    final mieScale = 1.0 + strain * 0.9;
    final stillness = 0.35 + sleep * 0.65;

    final altDeg = sunDir.altitude * radToDeg;
    // Photographic adaptation, in the shader's already-compressed units:
    // noon sits at 0.5 (the classic Preetham/ACES pairing), night opens up.
    final exposure = _lerp(1.25, 0.26, _smoothstep(-14, 6, altDeg));

    // Track the sun while it matters; hand over to a risen, lit moon at night.
    final wSun = 0.06 + _smoothstep(-14, -2, altDeg);
    final wMoon =
        _smoothstep(0, 12, moonDir.altitude * radToDeg) *
        (0.15 + 0.85 * illum) *
        (1 - _smoothstep(-14, -2, altDeg));
    final track = _circularMean(sunDir.azimuth, wSun, moonDir.azimuth, wMoon);

    return ResolvedScene(
      state: s,
      sunDir: sunDir,
      moonDir: moonDir,
      siderealRad: sidereal,
      latitudeRad: lat,
      sunDeclinationRad: dec,
      moonDeclinationRad: eqMoon.dec,
      moonHourAngleOffsetRad: moonOffset,
      moonIllumination: illum,
      sunrise: sunrise,
      sunset: sunset,
      moonrise: moonrise,
      moonset: moonset,
      turbidity: turbidity,
      mieScale: mieScale,
      exposure: exposure,
      stillness: stillness,
      trackAzimuthRad: track,
      planets: planets,
    );
  }

  static PlanetPosition _planet(
      Planet p, double epoch, double sidereal, double lat, double sunAltDeg) {
    final eq = planetEquatorial(p, epoch);
    final dir = horizontalDirection(eq.dec, sidereal - eq.ra, lat);
    final mag = planetMagnitude(p, eq.distanceAu);
    // Bright planets show from civil twilight, faint ones from nautical;
    // everything fades into the horizon's air.
    final darkEnough = mag < -1.5
        ? smoothstep(-2.0, -7.0, sunAltDeg)
        : smoothstep(-6.0, -11.0, sunAltDeg);
    final up = smoothstep(-0.5, 4.0, dir.altitude * radToDeg);
    final visibility = darkEnough * up;
    // Point brightness on a magnitude scale, Venus ≈ 1, +1 mag ≈ 0.12.
    final brightness = math.pow(10, -0.4 * (mag + 4.2)).toDouble().clamp(0.0, 1.0);
    return PlanetPosition(
      planet: p,
      dir: dir,
      magnitude: mag,
      elongationRad: eq.elongationRad,
      visibility: visibility,
      brightness: brightness,
    );
  }

  static double _frac(double v) => v - v.floorToDouble();
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _smoothstep(double e0, double e1, double x) =>
      smoothstep(e0, e1, x);

  static double _circularMean(double a, double wa, double b, double wb) {
    final x = math.cos(a) * wa + math.cos(b) * wb;
    final y = math.sin(a) * wa + math.sin(b) * wb;
    if (x == 0 && y == 0) return a;
    return wrapAngle(math.atan2(y, x));
  }
}
