import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'celestial_math.dart';
import 'celestial_scene.dart';
import 'sky_camera.dart';
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

final Float32List _coolPts = Float32List(kStarCount * 2);
final Float32List _warmPts = Float32List(kStarCount * 2);

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
  final moonDir = scene.moonDir;
  final moonUp = smoothstep(-0.05, 0.12, moonDir.y);
  final moonGlare = 0.75 * scene.moonIllumination * moonUp;
  final twinkleAmp = (1.2 - scene.stillness).clamp(0.15, 1.2);
  final horizonY = camera.principal.dy;
  var coolN = 0;
  var warmN = 0;

  for (var i = 0; i < kStarCount; i++) {
    final o = i * 4;
    final ra = pack[o];
    final dec = pack[o + 1];
    final mag = pack[o + 2];
    final bv = pack[o + 3];
    final dir = horizontalDirection(dec, wrapAngle(sidereal - ra), lat);
    if (dir.y < 0) continue;
    if (dir.dot(moonDir) > 0.9996) continue;
    final p = camera.project(dir);
    if (p == null || !camera.contains(p)) continue;
    if (p.dy > horizonY + 0.5) continue;

    final up = smoothstep(-0.5, 4.0, dir.altitude * radToDeg);
    var glare = 1.0;
    if (moonGlare > 0) {
      final m = dir.dot(moonDir).clamp(0.0, 1.0);
      glare = 1.0 - moonGlare * math.pow(m, 24).toDouble();
    }
    final twk =
        0.88 +
        0.12 * math.sin(time * (1.8 + (i % 7) * 0.35) * twinkleAmp + i * 0.17);
    final flux = math.pow(10, -0.4 * (mag + 1.44)).toDouble();
    final alpha =
        (vis * up * glare * twk * (0.16 + 0.84 * flux.clamp(0.0, 1.0))).clamp(
          0.0,
          1.0,
        );
    if (alpha < 0.02) continue;

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
    if (bv < 0.55) {
      _coolPts[coolN * 2] = p.dx;
      _coolPts[coolN * 2 + 1] = p.dy;
      coolN++;
    } else {
      _warmPts[warmN * 2] = p.dx;
      _warmPts[warmN * 2 + 1] = p.dy;
      warmN++;
    }
  }

  final faintA = (vis * 0.42).clamp(0.04, 0.55);
  if (coolN > 0) {
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(_coolPts, 0, coolN * 2),
      Paint()
        ..color = const Color(0xFFC5D4FF).withValues(alpha: faintA)
        ..strokeWidth = 1.05
        ..strokeCap = StrokeCap.round,
    );
  }
  if (warmN > 0) {
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(_warmPts, 0, warmN * 2),
      Paint()
        ..color = const Color(0xFFFFD4B4).withValues(alpha: faintA)
        ..strokeWidth = 1.05
        ..strokeCap = StrokeCap.round,
    );
  }
}

Color _tint(double bv) {
  final t = ((bv + 0.3) / 1.8).clamp(0.0, 1.0);
  return Color.lerp(const Color(0xFFC5D4FF), const Color(0xFFFFC8A0), t)!;
}
