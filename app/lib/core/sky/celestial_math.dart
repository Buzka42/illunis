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

// --- planets (Schlyter mean elements, epoch J2000; ~1° for ±50 y) --------

/// Days since 1999-12-31 00:00 UT, the epoch of the element set below.
double schlyterDay(double epochDaysJ2000) => epochDaysJ2000 + 1.5;

/// Days since J2000.0 (2000-01-01 12:00 UT) for a civil date's midnight.
double epochDaysForDate(int year, int month, int day) {
  // Meeus' JD for a Gregorian date at 0h, minus J2000.0.
  var y = year, m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = y ~/ 100;
  final b = 2 - a + a ~/ 4;
  final jd = (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524.5;
  return jd - 2451545.0;
}

enum Planet {
  mercury('Mercury', 'MERCURY'),
  venus('Venus', 'VENUS'),
  mars('Mars', 'MARS'),
  jupiter('Jupiter', 'JUPITER'),
  saturn('Saturn', 'SATURN');

  const Planet(this.name, this.label);
  final String name;
  final String label;
}

class _Elements {
  const _Elements(this.n0, this.n1, this.i0, this.i1, this.w0, this.w1, this.a,
      this.e0, this.e1, this.m0, this.m1);
  final double n0, n1, i0, i1, w0, w1, a, e0, e1, m0, m1;
}

const _sunElements =
    _Elements(0, 0, 0, 0, 282.9404, 4.70935e-5, 1.0, 0.016709, -1.151e-9, 356.0470, 0.9856002585);

const _planetElements = <Planet, _Elements>{
  Planet.mercury: _Elements(48.3313, 3.24587e-5, 7.0047, 5.00e-8, 29.1241, 1.01444e-5,
      0.387098, 0.205635, 5.59e-10, 168.6562, 4.0923344368),
  Planet.venus: _Elements(76.6799, 2.46590e-5, 3.3946, 2.75e-8, 54.8910, 1.38374e-5,
      0.723330, 0.006773, -1.302e-9, 48.0052, 1.6021302244),
  Planet.mars: _Elements(49.5574, 2.11081e-5, 1.8497, -1.78e-8, 286.5016, 2.92961e-5,
      1.523688, 0.093405, 2.516e-9, 18.6021, 0.5240207766),
  Planet.jupiter: _Elements(100.4542, 2.76854e-5, 1.3030, -1.557e-7, 273.8777, 1.64505e-5,
      5.20256, 0.048498, 4.469e-9, 19.8950, 0.0830853001),
  Planet.saturn: _Elements(113.6634, 2.38980e-5, 2.4886, -1.081e-7, 339.3939, 2.97661e-5,
      9.55475, 0.055546, -9.499e-9, 316.9670, 0.0334442282),
};

/// Heliocentric ecliptic rectangular coordinates, AU.
Vec3 _heliocentric(_Elements el, double d) {
  final n = (el.n0 + el.n1 * d) * degToRad;
  final i = (el.i0 + el.i1 * d) * degToRad;
  final w = (el.w0 + el.w1 * d) * degToRad;
  final e = el.e0 + el.e1 * d;
  final m = wrapAngle((el.m0 + el.m1 * d) * degToRad);
  var ecc = m + e * math.sin(m) * (1 + e * math.cos(m));
  for (var k = 0; k < 6; k++) {
    ecc = ecc - (ecc - e * math.sin(ecc) - m) / (1 - e * math.cos(ecc));
  }
  final xv = el.a * (math.cos(ecc) - e);
  final yv = el.a * math.sqrt(1 - e * e) * math.sin(ecc);
  final v = math.atan2(yv, xv);
  final r = math.sqrt(xv * xv + yv * yv);
  final vw = v + w;
  return Vec3(
    r * (math.cos(n) * math.cos(vw) - math.sin(n) * math.sin(vw) * math.cos(i)),
    r * (math.sin(n) * math.cos(vw) + math.cos(n) * math.sin(vw) * math.cos(i)),
    r * math.sin(vw) * math.sin(i),
  );
}

/// Geocentric ecliptic position of the Sun, AU (x toward the equinox).
Vec3 sunEcliptic(double epochDaysJ2000) {
  final d = schlyterDay(epochDaysJ2000);
  final el = _sunElements;
  final w = (el.w0 + el.w1 * d) * degToRad;
  final e = el.e0 + el.e1 * d;
  final m = wrapAngle((el.m0 + el.m1 * d) * degToRad);
  var ecc = m + e * math.sin(m) * (1 + e * math.cos(m));
  for (var k = 0; k < 6; k++) {
    ecc = ecc - (ecc - e * math.sin(ecc) - m) / (1 - e * math.cos(ecc));
  }
  final xv = math.cos(ecc) - e;
  final yv = math.sqrt(1 - e * e) * math.sin(ecc);
  final v = math.atan2(yv, xv);
  final r = math.sqrt(xv * xv + yv * yv);
  final lon = v + w;
  return Vec3(r * math.cos(lon), r * math.sin(lon), 0);
}

/// Ecliptic longitude of the Sun, radians.
double sunEclipticLongitude(double epochDaysJ2000) {
  final s = sunEcliptic(epochDaysJ2000);
  return wrapAngle(math.atan2(s.y, s.x));
}

/// Equatorial (RA, Dec) and distance (AU) of a planet as seen from Earth.
({double ra, double dec, double distanceAu, double elongationRad}) planetEquatorial(
    Planet p, double epochDaysJ2000) {
  final d = schlyterDay(epochDaysJ2000);
  final h = _heliocentric(_planetElements[p]!, d);
  final s = sunEcliptic(epochDaysJ2000);
  final g = h + s; // geocentric ecliptic
  final xe = g.x;
  final ye = g.y * math.cos(obliquityRad) - g.z * math.sin(obliquityRad);
  final ze = g.y * math.sin(obliquityRad) + g.z * math.cos(obliquityRad);
  final ra = math.atan2(ye, xe);
  final dec = math.atan2(ze, math.sqrt(xe * xe + ye * ye));
  final dist = g.length;
  final elong = math.acos((g.dot(s) / (dist * s.length)).clamp(-1.0, 1.0));
  return (ra: ra, dec: dec, distanceAu: dist, elongationRad: elong);
}

/// A rough visual magnitude, enough to decide how bright the point is.
double planetMagnitude(Planet p, double distanceAu) {
  final base = switch (p) {
    Planet.mercury => 0.2,
    Planet.venus => -4.2,
    Planet.mars => -0.5,
    Planet.jupiter => -2.4,
    Planet.saturn => 0.6,
  };
  // Inverse-square about a typical distance, in magnitudes.
  final typical = switch (p) {
    Planet.mercury => 1.0,
    Planet.venus => 1.0,
    Planet.mars => 1.4,
    Planet.jupiter => 5.5,
    Planet.saturn => 10.0,
  };
  // Inner planets near us are thin crescents, so the inverse-square gain is
  // mostly lost to phase; cap at their real brightest.
  final floor = switch (p) {
    Planet.mercury => -1.9,
    Planet.venus => -4.6,
    _ => -3.0,
  };
  return math.max(floor, base + 5 * math.log(distanceAu / typical) / math.ln10);
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
