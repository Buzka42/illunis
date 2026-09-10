import 'dart:math' as math;
import 'dart:ui';

import 'celestial_math.dart';
import 'celestial_scene.dart';
import 'sky_camera.dart';
import 'sky_shader.dart';
import 'star_catalog.dart';

/// One row of [kStarPack].
class CatalogStar {
  const CatalogStar({
    required this.index,
    required this.raRad,
    required this.decRad,
    required this.vMag,
    required this.bv,
  });

  final int index;
  final double raRad;
  final double decRad;
  final double vMag;
  final double bv;
}

CatalogStar catalogStarAt(int i) {
  final p = kStarPack;
  final o = i * 4;
  return CatalogStar(
    index: i,
    raRad: p[o],
    decRad: p[o + 1],
    vMag: p[o + 2],
    bv: p[o + 3],
  );
}

CatalogStar? catalogStarByName(String name) {
  final i = kStarNameIndex[name];
  if (i == null) return null;
  return catalogStarAt(i);
}

/// Horizontal direction of a catalog star at the scene's sidereal time.
Vec3 catalogStarDirection(CatalogStar star, double siderealRad, double latRad) {
  return horizontalDirection(
    star.decRad,
    wrapAngle(siderealRad - star.raRad),
    latRad,
  );
}

/// Same twilight ramp as the old shader field: nothing by civil dusk,
/// full by astronomical night.
double catalogStarVisibility(double sunAltDeg) =>
    smoothstep(-5, -15, sunAltDeg);

// Logarithmic alpha bins retain faint-star magnitude, air mass, glare and
// twinkle while bounding the faint field to 48 Canvas calls.
const _bins = 24;
final _points = List.generate(_bins * 2, (_) => <Offset>[]);
// Catalog-only work is fixed for the lifetime of the bundled J2000 table.
final _equatorial = List<Vec3>.generate(kStarCount, (i) {
  final ra = kStarPack[i * 4], dec = kStarPack[i * 4 + 1];
  final c = math.cos(dec);
  return Vec3(c * math.cos(ra), math.sin(dec), c * math.sin(ra));
}, growable: false);
final _intensities = List<double>.generate(
  kStarCount,
  (i) => starIntensity(kStarPack[i * 4 + 2]),
  growable: false,
);

/// Exposure-adapted V magnitude. The flux follows Pogson's law before a
/// logarithmic eye response; no common brightness floor for faint stars.
double starIntensity(double magnitude) {
  final flux = math.pow(10, -0.4 * magnitude).toDouble();
  return (math.log(1 + 40 * flux) / math.log(1 + 40 * math.pow(10, 0.576)))
      .clamp(0.0, 1.0);
}

double starExtinction(double altitudeRad, double turbidity) {
  if (altitudeRad <= 0) return 0;
  final degrees = altitudeRad * radToDeg;
  final airMass =
      1 /
      (math.sin(altitudeRad) + 0.50572 * math.pow(degrees + 6.07995, -1.6364));
  final coefficient = 0.12 + 0.025 * turbidity;
  return math.pow(10, -0.4 * coefficient * (airMass - 1)).toDouble();
}

double _binAlpha(int bin) => 0.004 * math.pow(250, bin / (_bins - 1));

void paintCatalogStars(
  Canvas canvas, {
  required ResolvedScene scene,
  required SkyCamera camera,
  required double time,
}) {
  final vis = catalogStarVisibility(scene.sunDir.altitude * radToDeg);
  if (vis < 0.002) return;

  final pack = kStarPack;
  final lat = scene.latitudeRad;
  final sidereal = scene.siderealRad;
  final sinLat = math.sin(lat), cosLat = math.cos(lat);
  final sinSidereal = math.sin(sidereal), cosSidereal = math.cos(sidereal);
  final forward = camera.forward, right = camera.right;
  final moonDir = scene.moonDir;
  final moonUp = smoothstep(-0.05, 0.12, moonDir.y);
  final moonGlare = 0.75 * scene.moonIllumination * moonUp;
  final twinkleAmp = (1.2 - scene.stillness).clamp(0.15, 1.2);
  final horizonY = camera.principal.dy;
  for (final points in _points) {
    points.clear();
  }

  for (var i = 0; i < kStarCount; i++) {
    final o = i * 4;
    final mag = pack[o + 2];
    final bv = pack[o + 3];
    final eq = _equatorial[i];
    final q = cosSidereal * eq.x + sinSidereal * eq.z;
    final dir = Vec3(
      cosSidereal * eq.z - sinSidereal * eq.x,
      sinLat * eq.y + cosLat * q,
      sinLat * q - cosLat * eq.y,
    );
    if (dir.y < 0) continue;
    if (dir.dot(moonDir) > math.cos(SkyShader.moonAngularRadius)) continue;
    final denom = 1 + dir.dot(forward);
    if (denom < 0.08) continue;
    final k = 2 * camera.focal / denom;
    final p = Offset(
      camera.principal.dx + dir.dot(right) * k,
      camera.principal.dy - dir.y * k,
    );
    if (!camera.contains(p)) continue;
    if (p.dy > horizonY + 0.5) continue;

    final up = starExtinction(dir.altitude, scene.turbidity);
    var glare = 1.0;
    if (moonGlare > 0) {
      final m = dir.dot(moonDir).clamp(0.0, 1.0);
      glare = 1.0 - moonGlare * math.pow(m, 24).toDouble();
    }
    final twk =
        0.88 +
        0.12 * math.sin(time * (1.8 + (i % 7) * 0.35) * twinkleAmp + i * 0.17);
    final alpha = (vis * up * glare * twk * _intensities[i]).clamp(0.0, 1.0);
    if (alpha < 0.004) continue;

    if (mag <= 1.9) {
      final size = (0.7 + 1.6 * math.pow(10, -0.15 * (mag + 1.44))).clamp(
        0.7,
        2.6,
      );
      canvas.drawCircle(
        p,
        size * 0.55,
        Paint()..color = _tint(bv).withValues(alpha: alpha),
      );
      continue;
    }
    final bin = (math.log(alpha / 0.004) / math.log(250) * (_bins - 1))
        .round()
        .clamp(0, _bins - 1);
    _points[bin + (bv < 0.55 ? 0 : _bins)].add(p);
  }

  for (var i = 0; i < _points.length; i++) {
    if (_points[i].isEmpty) continue;
    final tint = i < _bins ? const Color(0xFFC5D4FF) : const Color(0xFFFFD4B4);
    canvas.drawPoints(
      PointMode.points,
      _points[i],
      Paint()
        ..color = tint.withValues(alpha: _binAlpha(i % _bins))
        ..strokeWidth = 1.05
        ..strokeCap = StrokeCap.round,
    );
  }
}

Color _tint(double bv) {
  final t = ((bv + 0.3) / 1.8).clamp(0.0, 1.0);
  return Color.lerp(const Color(0xFFC5D4FF), const Color(0xFFFFC8A0), t)!;
}
