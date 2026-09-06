/// Positional astronomy, reduced to what a sky needs and nothing the
/// backend might be tempted to depend on.
///
/// Accuracy target: the sun within ~1° and rise/set within a few minutes for
/// a given local solar time. That is enough for the picture to be honest;
/// a real ephemeris is a backend concern (see docs/BACKEND_PLAN.md).
library;

import 'dart:math' as math;

const double degToRad = math.pi / 180;
const double radToDeg = 180 / math.pi;

/// Obliquity of the ecliptic, J2000.
const double obliquityRad = 23.4393 * degToRad;

/// A unit direction in the observer's horizontal frame.
///
/// `x` east, `y` up, `z` south — so north is `-z` and azimuth is measured
/// from north through east, the way a compass reads.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x, y, z;

  static const zero = Vec3(0, 0, 0);
  static const up = Vec3(0, 1, 0);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  double get length => math.sqrt(dot(this));
  Vec3 get normalized {
    final l = length;
    return l == 0 ? this : Vec3(x / l, y / l, z / l);
  }

  /// Altitude above the horizon, radians.
  double get altitude => math.asin(y.clamp(-1.0, 1.0));

  /// Azimuth from north through east, radians in `[0, 2π)`.
  double get azimuth {
    final a = math.atan2(x, -z);
    return a < 0 ? a + 2 * math.pi : a;
  }

  /// Rotate about a unit [axis] by [angle] radians (right-hand rule).
  Vec3 rotated(Vec3 axis, double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    final d = axis.dot(this);
    return this * c + axis.cross(this) * s + axis * (d * (1 - c));
  }

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)})';
}

/// Direction from horizontal coordinates.
Vec3 directionFromAltAz(double altRad, double azRad) {
  final ca = math.cos(altRad);
  return Vec3(ca * math.sin(azRad), math.sin(altRad), -ca * math.cos(azRad));
}

/// Solar declination for a day of the year, radians. Spencer/Cooper form;
/// within 0.3° of the almanac, which the eye cannot see.
double solarDeclination(double dayOfYear) {
  return 23.44 * degToRad * math.sin(2 * math.pi * (284 + dayOfYear) / 365.0);
}

/// Ecliptic longitude of the sun, radians, zero at the March equinox.
double solarEclipticLongitude(double dayOfYear) {
  return ((dayOfYear - 80.0) / 365.25) * 2 * math.pi;
}

/// Hour angle of the sun, radians, negative before local solar noon.
double solarHourAngle(double timeOfDay, double solarNoon) {
  return (timeOfDay - solarNoon) * 2 * math.pi;
}

/// Horizontal direction of a body with declination [decRad] at hour angle
/// [hourAngleRad] for an observer at [latRad].
Vec3 horizontalDirection(double decRad, double hourAngleRad, double latRad) {
  final sinLat = math.sin(latRad), cosLat = math.cos(latRad);
  final sinDec = math.sin(decRad), cosDec = math.cos(decRad);
  final cosH = math.cos(hourAngleRad), sinH = math.sin(hourAngleRad);
  final y = sinLat * sinDec + cosLat * cosDec * cosH;
  // Azimuth from south, westward positive — then turned to compass bearing.
  final azFromSouth = math.atan2(
    sinH,
    cosH * sinLat - math.tan(decRad) * cosLat,
  );
  final az = azFromSouth + math.pi;
  final alt = math.asin(y.clamp(-1.0, 1.0));
  return directionFromAltAz(alt, az);
}

/// Equatorial (RA, Dec) of a point on the ecliptic at longitude [lambda].
({double ra, double dec}) equatorialFromEcliptic(double lambda) {
  final sinL = math.sin(lambda), cosL = math.cos(lambda);
  final dec = math.asin(math.sin(obliquityRad) * sinL);
  final ra = math.atan2(math.cos(obliquityRad) * sinL, cosL);
  return (ra: ra, dec: dec);
}

/// Hour angle at which a body of declination [decRad] reaches altitude
/// [altRad]; null when it never does (midnight sun / polar night).
double? hourAngleAtAltitude(double decRad, double latRad, double altRad) {
  final c =
      (math.sin(altRad) - math.sin(latRad) * math.sin(decRad)) /
      (math.cos(latRad) * math.cos(decRad));
  if (c < -1 || c > 1) return null;
  return math.acos(c);
}

/// Standard rise/set altitude: refraction plus the disc's semi-diameter.
const double riseSetAltitudeRad = -0.833 * degToRad;

/// Civil twilight ends when the sun is 6° down; nautical 12°; astronomical 18°.
const double civilTwilightRad = -6 * degToRad;
const double astronomicalTwilightRad = -18 * degToRad;

/// Illuminated fraction of the moon's disc for a phase in `0..1`.
double moonIlluminatedFraction(double phase) {
  return (1 - math.cos(phase * 2 * math.pi)) / 2;
}

/// Mean synodic month, days.
const double synodicMonthDays = 29.530588853;

/// Moon phase in `0..1` from a UTC instant, against a known new moon.
double moonPhaseFor(DateTime utc) {
  // New moon, 2000-01-06 18:14 UTC.
  final epoch = DateTime.utc(2000, 1, 6, 18, 14);
  final days = utc.difference(epoch).inSeconds / 86400.0;
  final cycles = days / synodicMonthDays;
  return cycles - cycles.floorToDouble();
}

double smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double wrapAngle(double a) {
  final twoPi = 2 * math.pi;
  var r = a % twoPi;
  if (r < 0) r += twoPi;
  return r;
}

String formatHours(double fraction) {
  final total =
      ((fraction - fraction.floorToDouble()) * 24 * 60).round() % 1440;
  final h = total ~/ 60, m = total % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String formatDuration(double dayFraction) {
  final total = (dayFraction * 24 * 60).round();
  final h = total ~/ 60, m = total % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
