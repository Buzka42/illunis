import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'celestial_glyphs.dart';
import 'celestial_math.dart';
import 'celestial_scene.dart';
import 'sky_camera.dart';
import 'sky_shader.dart';

/// The instrument layer over the sky: horizon, compass scale, altitude
/// circles, the sun's and moon's paths for the day with hour ticks, and a
/// live readout beside each body. Everything is projected through the same
/// [SkyCamera] the shader inverts, so annotations sit on what they annotate.
class SkyOverlayPainter extends CustomPainter {
  SkyOverlayPainter({
    required this.scene,
    required this.azimuthRad,
    required this.textScale,
    this.showPaths = true,
  });

  final ResolvedScene scene;
  final double azimuthRad;
  final double textScale;
  final bool showPaths;

  static const _light = Color(0xFFEEF1F6);
  static const _slate = Color(0xFF1B2433);

  /// Sky-band ink: light under a dark sky, deep slate once the sun is well up.
  /// The ground band always takes light ink.
  late final Color _ink = Color.lerp(_light, _slate, scene.skyInkBlend)!;
  static const _mono = 'JetBrains Mono';

  static final Map<String, TextPainter> _textCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 8) return;
    final cam = SkyCamera(size: size, azimuthRad: azimuthRad);
    final day = scene.dayness;
    // Type over a bright sky needs a shadow; over night, none.
    final slateness = scene.skyInkBlend;
    final shadow = day * 0.75 * (1 - slateness);

    _paintAltitudeCircles(canvas, cam, size);
    _paintHorizon(canvas, cam, size, shadow);
    if (showPaths) {
      _paintPath(
        canvas,
        cam,
        size,
        at: scene.moonDirectionAt,
        color: const Color(0xFFB9C6E0),
        alphaAbove: 0.24,
        alphaBelow: 0.09,
        hourLabels: false,
        shadow: shadow,
      );
      _paintPath(
        canvas,
        cam,
        size,
        at: scene.sunDirectionAt,
        color: _ink,
        alphaAbove: 0.38,
        alphaBelow: 0.09,
        hourLabels: true,
        shadow: shadow,
        // No tick or hour under the sun's own ring and readout.
        avoid: cam.project(scene.sunDir),
        avoidRadius: SkyShader.sunAngularRadius * cam.focal * 2.6 + 40,
      );
    }
    final edgeIndicators = <_EdgeIndicator>[];
    _paintBody(
      canvas,
      cam,
      size,
      dir: scene.moonDir,
      ringRadius: SkyShader.moonAngularRadius * cam.focal * 1.45,
      label: 'MOON',
      glyph: CelestialGlyph.moon,
      lines: [
        '${(scene.moonIllumination * 100).round().toString().padLeft(3)}%  ${scene.describeMoonPhase().toUpperCase()}',
        _altAz(scene.moonDir),
      ],
      shadow: shadow,
      dim: scene.state.weather?.isClear == false ? 1.0 : 0.8,
      edgeIndicators: edgeIndicators,
    );
    _paintBody(
      canvas,
      cam,
      size,
      dir: scene.sunDir,
      ringRadius: SkyShader.sunAngularRadius * cam.focal * 2.6 + 10,
      label: 'SUN',
      glyph: CelestialGlyph.sun,
      lines: [scene.describeTwilight().toUpperCase(), _altAz(scene.sunDir)],
      shadow: shadow,
      dim: 1.0,
      edgeIndicators: edgeIndicators,
    );
    final occupiedYs = _paintEdgeIndicators(
      canvas,
      cam,
      size,
      edgeIndicators,
    );
    _paintPlanets(canvas, cam, size, shadow, occupiedYs: occupiedYs);
  }

  String _altAz(Vec3 d) {
    final alt = d.altitude * radToDeg;
    final az = d.azimuth * radToDeg;
    final sign = alt >= 0 ? '+' : '−';
    return 'ALT $sign${alt.abs().toStringAsFixed(1).padLeft(4)}°  AZ ${az.toStringAsFixed(1).padLeft(5)}°';
  }

  // --- horizon and compass -------------------------------------------------

  void _paintHorizon(Canvas canvas, SkyCamera cam, Size size, double shadow) {
    final y = cam.principal.dy;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = _light.withValues(alpha: 0.26)
        ..strokeWidth = 1,
    );
    final tick = Paint()
      ..color = _light.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (var deg = 0; deg < 360; deg += 5) {
      final p = cam.project(directionFromAltAz(0, deg * degToRad));
      if (p == null || p.dx < -20 || p.dx > size.width + 20) continue;
      final major = deg % 30 == 0;
      final mid = deg % 15 == 0;
      final len = major ? 7.0 : (mid ? 4.5 : 2.5);
      canvas.drawLine(Offset(p.dx, y), Offset(p.dx, y + len), tick);
      if (major) {
        final label = switch (deg) {
          0 => 'N',
          90 => 'E',
          180 => 'S',
          270 => 'W',
          _ => deg.toString().padLeft(3, '0'),
        };
        _text(
          canvas,
          label,
          Offset(p.dx, y + 10),
          size: 9,
          alpha: deg % 90 == 0 ? 0.7 : 0.38,
          weight: deg % 90 == 0 ? 600 : 400,
          anchor: Alignment.topCenter,
          shadow: 0,
          color: _light,
        );
      }
    }
  }

  void _paintAltitudeCircles(Canvas canvas, SkyCamera cam, Size size) {
    final paint = Paint()
      ..color = _ink.withValues(alpha: 0.055)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (var alt = 15; alt <= 75; alt += 15) {
      final path = Path();
      var open = false;
      for (var i = 0; i <= 180; i++) {
        final az = i * 2 * degToRad;
        final p = cam.project(directionFromAltAz(alt * degToRad, az));
        if (p == null ||
            p.dx < -400 ||
            p.dx > size.width + 400 ||
            p.dy < -400) {
          open = false;
          continue;
        }
        if (!open) {
          path.moveTo(p.dx, p.dy);
          open = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
      final lp = cam.project(directionFromAltAz(alt * degToRad, azimuthRad));
      // Not under the header's clock.
      if (lp != null && lp.dy > 68) {
        _text(
          canvas,
          '$alt°',
          Offset(size.width - 12, lp.dy - 2),
          size: 8.5,
          alpha: 0.22,
          anchor: Alignment.bottomRight,
          shadow: 0,
        );
      }
    }
  }

  // --- paths ---------------------------------------------------------------

  void _paintPath(
    Canvas canvas,
    SkyCamera cam,
    Size size, {
    required Vec3 Function(double t) at,
    required Color color,
    required double alphaAbove,
    required double alphaBelow,
    required bool hourLabels,
    required double shadow,
    Offset? avoid,
    double avoidRadius = 0,
  }) {
    const steps = 24 * 20; // three-minute samples
    final above = Path();
    final belowDots = <Offset>[];
    var open = false;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final d = at(t);
      final p = cam.project(d);
      final onScreen =
          p != null &&
          p.dx > -60 &&
          p.dx < size.width + 60 &&
          p.dy > -60 &&
          p.dy < size.height + 60;
      if (!onScreen) {
        open = false;
        continue;
      }
      if (d.y >= 0) {
        if (!open) {
          above.moveTo(p.dx, p.dy);
          open = true;
        } else {
          above.lineTo(p.dx, p.dy);
        }
      } else {
        open = false;
        if (i % 4 == 0) belowDots.add(p);
      }
    }
    canvas.save();
    final moonAt = cam.project(scene.moonDir);
    if (moonAt != null && scene.moonDir.y > 0 && cam.contains(moonAt)) {
      final side = moonAt.dx < size.width * 0.5 ? 1.0 : -1.0;
      final radius = SkyShader.moonAngularRadius * cam.focal * 1.45;
      final base =
          moonAt +
          Offset(
            side * (radius * math.cos(0.5) + 38),
            -radius * math.sin(0.5) - 14,
          );
      final block = Rect.fromLTRB(
        base.dx - (side < 0 ? 165 * textScale : 2),
        base.dy - 19 * textScale,
        base.dx + (side > 0 ? 165 * textScale : 2),
        base.dy + 3 + 25 * textScale,
      );
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRect(block),
      );
    }
    canvas.drawPath(
      above,
      Paint()
        ..color = color.withValues(alpha: alphaAbove)
        ..strokeWidth = 0.75
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
    if (belowDots.isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        belowDots,
        Paint()
          ..color = color.withValues(alpha: alphaBelow)
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round,
      );
    }

    // Hour ticks, perpendicular to the path; labels every third hour.
    final tickPaint = Paint()
      ..color = color.withValues(alpha: alphaAbove)
      ..strokeWidth = 0.75;
    for (var h = 0; h < 24; h++) {
      final t = h / 24;
      final d = at(t);
      final p = cam.project(d);
      if (p == null || !cam.contains(p)) continue;
      final ahead = cam.project(at(t + 1 / 480));
      if (ahead == null) continue;
      final dir = ahead - p;
      if (dir.distance == 0) continue;
      final n = Offset(-dir.dy, dir.dx) / dir.distance;
      final below = d.y < 0;
      final len = below ? 2.5 : (h % 3 == 0 ? 6.0 : 3.5);
      final paint = below
          ? (Paint()
              ..color = color.withValues(alpha: alphaBelow * 1.4)
              ..strokeWidth = 1)
          : tickPaint;
      if (avoid != null && (p - avoid).distance < avoidRadius) continue;
      final moonAt = cam.project(scene.moonDir);
      // A path's hour must not land in the lunar leader/readout block.
      // The path is also clipped behind the readout above.
      if (moonAt != null &&
          scene.moonDir.y > 0 &&
          (p.dx - moonAt.dx).abs() < 170 * textScale &&
          p.dy > moonAt.dy - 65 * textScale &&
          p.dy < moonAt.dy + 20 * textScale) {
        continue;
      }
      canvas.drawLine(p - n * len, p + n * len, paint);
      if (hourLabels && !below && h % 3 == 0) {
        _text(
          canvas,
          h.toString().padLeft(2, '0'),
          p + n * 10,
          size: 8.5,
          alpha: 0.45,
          anchor: n.dy < 0 ? Alignment.bottomCenter : Alignment.topCenter,
          shadow: shadow,
        );
      }
    }
  }

  // --- bodies --------------------------------------------------------------

  void _paintBody(
    Canvas canvas,
    SkyCamera cam,
    Size size, {
    required Vec3 dir,
    required double ringRadius,
    required String label,
    required CelestialGlyph glyph,
    required List<String> lines,
    required double shadow,
    required double dim,
    List<_EdgeIndicator>? edgeIndicators,
  }) {
    final p = cam.project(dir);
    final visible = p != null && cam.contains(p) && dir.y > -0.05;
    if (!visible) {
      if (edgeIndicators != null) {
        edgeIndicators.add(
          _EdgeIndicator(dir: dir, label: label, shadow: shadow, dim: dim),
        );
      } else {
        _renderSingleEdgeIndicator(
          canvas,
          cam,
          size,
          _EdgeIndicator(dir: dir, label: label, shadow: shadow, dim: dim),
          cam.principal.dy - 28.0,
          true,
        );
      }
      return;
    }
    if (dir.y < 0) return;

    final ring = Paint()
      ..color = _ink.withValues(alpha: 0.5 * dim)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    // A broken ring: four arcs, so it reads as an instrument, not a badge.
    const gap = 0.35;
    for (var q = 0; q < 4; q++) {
      final start = q * math.pi / 2 + gap / 2 + math.pi / 4;
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: ringRadius),
        start,
        math.pi / 2 - gap,
        false,
        ring,
      );
    }

    // Readout to the side with more room, leader drawn to the ring.
    final toRight = p.dx < size.width * 0.5;
    final dx = toRight ? 1.0 : -1.0;
    final start =
        p +
        Offset(dx * ringRadius * math.cos(0.5), -ringRadius * math.sin(0.5));
    final elbow = start + Offset(dx * 14, -14);
    final end = elbow + Offset(dx * 18, 0);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(end.dx, end.dy),
      ring,
    );
    final anchor = toRight ? Alignment.bottomLeft : Alignment.bottomRight;
    final anchorBelow = toRight ? Alignment.topLeft : Alignment.topRight;
    final base = end + Offset(dx * 6, 0);
    // The glyph leads the label on the side away from the leader.
    const glyphSize = 11.0;
    final labelWidth = _measure(label, size: 9.5, weight: 600).width;
    final glyphAt = toRight
        ? base + const Offset(glyphSize / 2, -3 - glyphSize / 2 - 1)
        : base +
              Offset(-labelWidth - 6 - glyphSize / 2, -3 - glyphSize / 2 - 1);
    glyph.paint(
      canvas,
      glyphAt,
      glyphSize,
      Paint()
        ..color = _ink.withValues(alpha: 0.85 * dim)
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      label,
      base + Offset(toRight ? glyphSize + 6 : 0, -3),
      size: 9.5,
      alpha: 0.85 * dim,
      weight: 600,
      anchor: anchor,
      shadow: shadow,
    );
    var y = 3.0;
    for (final line in lines) {
      _text(
        canvas,
        line,
        base + Offset(0, y),
        size: 8.5,
        alpha: 0.6 * dim,
        anchor: anchorBelow,
        shadow: shadow,
      );
      y += 12 * textScale;
    }
  }

  // --- planets -------------------------------------------------------------

  void _paintPlanets(
    Canvas canvas,
    SkyCamera cam,
    Size size,
    double shadow, {
    required ({List<double> left, List<double> right}) occupiedYs,
  }) {
    // Off-screen planets go on a rail at each edge, highest first, so they
    // never land on the sun's or moon's edge readout.
    final railLeft = <PlanetPosition>[], railRight = <PlanetPosition>[];
    for (final pl in scene.planets) {
      if (pl.visibility < 0.04) continue;
      final p = cam.project(pl.dir);
      final a = pl.visibility;
      if (p == null || !cam.contains(p)) {
        if (a < 0.3 || pl.dir.y <= 0) continue;
        var rel = pl.dir.azimuth - azimuthRad;
        while (rel > math.pi) {
          rel -= 2 * math.pi;
        }
        while (rel < -math.pi) {
          rel += 2 * math.pi;
        }
        (rel > 0 ? railRight : railLeft).add(pl);
        continue;
      }
      final ink = Paint()
        ..color = _ink.withValues(alpha: 0.7 * a)
        ..strokeWidth = 0.75;
      // A short leader from the point, glyph and name on the open side.
      final toRight = p.dx < size.width * 0.5;
      final dx = toRight ? 1.0 : -1.0;
      final start = p + Offset(dx * 5, -5);
      final end = start + Offset(dx * 9, -9);
      canvas.drawLine(start, end, ink);
      const glyphSize = 10.0;
      final glyphAt = end + Offset(dx * (4 + glyphSize / 2), -1);
      CelestialGlyph.forPlanet(pl.planet).paint(
        canvas,
        glyphAt,
        glyphSize,
        Paint()
          ..color = _ink.withValues(alpha: 0.8 * a)
          ..strokeWidth = 0.9,
      );
      final textAt = end + Offset(dx * (glyphSize + 9), 0);
      _text(
        canvas,
        pl.planet.label,
        textAt + const Offset(0, -1),
        size: 8.5,
        alpha: 0.7 * a,
        weight: 600,
        anchor: toRight ? Alignment.bottomLeft : Alignment.bottomRight,
        shadow: shadow,
      );
      _text(
        canvas,
        'ALT +${(pl.dir.altitude * radToDeg).toStringAsFixed(1).padLeft(4)}°  M ${pl.magnitude.toStringAsFixed(1)}',
        textAt + const Offset(0, 1),
        size: 7.5,
        alpha: 0.45 * a,
        anchor: toRight ? Alignment.topLeft : Alignment.topRight,
        shadow: shadow,
      );
    }

    for (final (rail, right) in [(railLeft, false), (railRight, true)]) {
      rail.sort((a, b) => b.dir.y.compareTo(a.dir.y));
      final x = right ? size.width - 15.0 : 15.0;
      final occupied = right ? occupiedYs.right : occupiedYs.left;
      var y = 96.0;
      for (var i = 0; i < rail.length; i++) {
        final pl = rail[i];
        while (occupied.any((oy) => (oy - y).abs() < 16.0)) {
          y += 18.0;
        }
        final paint = Paint()
          ..color = _ink.withValues(alpha: 0.5 * pl.visibility)
          ..strokeWidth = 0.8;
        CelestialGlyph.forPlanet(
          pl.planet,
        ).paint(canvas, Offset(x, y), 9, paint);
        final ax = x + (right ? 8.5 : -8.5);
        final tip = x + (right ? 11 : -11);
        canvas.drawPath(
          Path()
            ..moveTo(ax, y - 2.5)
            ..lineTo(tip, y)
            ..lineTo(ax, y + 2.5),
          paint..style = PaintingStyle.stroke,
        );
        y += 18.0;
      }
    }
  }

  ({List<double> left, List<double> right}) _paintEdgeIndicators(
    Canvas canvas,
    SkyCamera cam,
    Size size,
    List<_EdgeIndicator> indicators,
  ) {
    if (indicators.isEmpty) return (left: <double>[], right: <double>[]);
    final left = <_PositionedIndicator>[];
    final right = <_PositionedIndicator>[];

    final yLo = math.min(56.0, cam.principal.dy - 4.0);
    final yHi = math.max(yLo, cam.principal.dy - 28.0);

    for (final ind in indicators) {
      var rel = ind.dir.azimuth - azimuthRad;
      while (rel > math.pi) {
        rel -= 2 * math.pi;
      }
      while (rel < -math.pi) {
        rel += 2 * math.pi;
      }
      final isRight = rel > 0;
      final altDeg = ind.dir.altitude * radToDeg;
      final yGuess = cam.principal.dy - altDeg * degToRad * cam.focal * 0.9;
      final clampedY = yGuess.clamp(yLo, yHi);
      final item = _PositionedIndicator(ind, clampedY, isRight);
      if (isRight) {
        right.add(item);
      } else {
        left.add(item);
      }
    }

    final occupiedLeft = <double>[];
    final occupiedRight = <double>[];

    for (final (rail, occupiedList) in [
      (left, occupiedLeft),
      (right, occupiedRight),
    ]) {
      if (rail.isEmpty) continue;
      rail.sort((a, b) => a.y.compareTo(b.y));
      const spacing = 20.0;
      for (var i = 1; i < rail.length; i++) {
        if (rail[i].y < rail[i - 1].y + spacing) {
          rail[i].y = rail[i - 1].y + spacing;
        }
      }
      if (rail.last.y > yHi) {
        final overflow = rail.last.y - yHi;
        for (var i = rail.length - 1; i >= 0; i--) {
          rail[i].y -= overflow;
        }
      }
      if (rail.first.y < yLo) {
        final underflow = yLo - rail.first.y;
        for (var i = 0; i < rail.length; i++) {
          rail[i].y = (rail[i].y + underflow).clamp(yLo, yHi);
        }
      }

      for (final item in rail) {
        _renderSingleEdgeIndicator(
          canvas,
          cam,
          size,
          item.indicator,
          item.y,
          item.right,
        );
        occupiedList.add(item.y);
      }
    }

    return (left: occupiedLeft, right: occupiedRight);
  }

  void _renderSingleEdgeIndicator(
    Canvas canvas,
    SkyCamera cam,
    Size size,
    _EdgeIndicator ind,
    double y,
    bool right,
  ) {
    final x = right ? size.width - 14.0 : 14.0;
    final altDeg = ind.dir.altitude * radToDeg;
    final paint = Paint()
      ..color = _ink.withValues(alpha: 0.6 * ind.dim)
      ..strokeWidth = 1;
    final tip = Offset(x + (right ? 4 : -4), y);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + (right ? -5 : 5), tip.dy - 4)
        ..lineTo(tip.dx + (right ? -5 : 5), tip.dy + 4)
        ..close(),
      paint..style = PaintingStyle.stroke,
    );
    final text =
        '${ind.label} ${(ind.dir.azimuth * radToDeg).round().toString().padLeft(3, '0')}°  '
        '${altDeg >= 0 ? '+' : '−'}${altDeg.abs().toStringAsFixed(0)}°';
    _text(
      canvas,
      text,
      Offset(x + (right ? -10 : 10), y),
      size: 8.5,
      alpha: 0.7 * ind.dim,
      anchor: right ? Alignment.centerRight : Alignment.centerLeft,
      shadow: ind.shadow,
    );
  }

  // --- type ----------------------------------------------------------------

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    required double size,
    required double alpha,
    required Alignment anchor,
    required double shadow,
    int weight = 400,
    Color? color,
  }) {
    // Shadow is bucketed so a slowly changing sky does not defeat the cache.
    final sh = (shadow * 4).round() / 4;
    final ink = color ?? _ink;
    final key =
        '$s|$size|$weight|${(alpha * 100).round()}|$textScale|$sh|${ink.toARGB32()}';
    final tp = _textCache.putIfAbsent(key, () {
      final p = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: _mono,
            fontSize: size * textScale,
            fontVariations: [ui.FontVariation('wght', weight.toDouble())],
            color: (color ?? _ink).withValues(alpha: alpha),
            letterSpacing: 0.4,
            height: 1.0,
            // Type over a noon sky keeps a whisper of shadow; night has none.
            shadows: sh > 0
                ? [
                    Shadow(
                      color: Color.fromRGBO(
                        10,
                        18,
                        32,
                        (sh * 1.6).clamp(0.0, 1.0) * alpha,
                      ),
                      blurRadius: 3,
                      offset: const Offset(0, 0.6),
                    ),
                    Shadow(
                      color: Color.fromRGBO(
                        10,
                        18,
                        32,
                        (sh * 0.9).clamp(0.0, 1.0) * alpha,
                      ),
                      blurRadius: 0.8,
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return p;
    });
    final w = tp.width, h = tp.height;
    final origin = Offset(
      at.dx - (anchor.x + 1) / 2 * w,
      at.dy - (anchor.y + 1) / 2 * h,
    );
    tp.paint(canvas, origin);
  }

  Size _measure(String s, {required double size, int weight = 400}) {
    final key = 'm|$s|$size|$weight|$textScale';
    final tp = _textCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: _mono,
            fontSize: size * textScale,
            fontVariations: [ui.FontVariation('wght', weight.toDouble())],
            letterSpacing: 0.4,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    return tp.size;
  }

  @override
  bool shouldRepaint(SkyOverlayPainter old) => true;
}

class _EdgeIndicator {
  const _EdgeIndicator({
    required this.dir,
    required this.label,
    required this.shadow,
    required this.dim,
  });

  final Vec3 dir;
  final String label;
  final double shadow;
  final double dim;
}

class _PositionedIndicator {
  _PositionedIndicator(this.indicator, this.y, this.right);

  final _EdgeIndicator indicator;
  double y;
  final bool right;
}

