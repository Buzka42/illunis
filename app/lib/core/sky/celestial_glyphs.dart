import 'dart:ui';

import 'celestial_math.dart';

/// The standard astronomical symbols, drawn as strokes in a unit box.
///
/// ☉ ☽ ☿ ♀ ♂ ♃ ♄ — no font, no bitmap. They share one stroke weight with the
/// rings and hairlines around them, take the instrument ink, and are crisp
/// at any density. [paint] draws a glyph centred on [center] at [size].
enum CelestialGlyph {
  sun,
  moon,
  mercury,
  venus,
  mars,
  jupiter,
  saturn;

  static CelestialGlyph forPlanet(Planet p) => switch (p) {
        Planet.mercury => mercury,
        Planet.venus => venus,
        Planet.mars => mars,
        Planet.jupiter => jupiter,
        Planet.saturn => saturn,
      };

  void paint(Canvas canvas, Offset center, double size, Paint stroke) {
    canvas.save();
    canvas.translate(center.dx - size / 2, center.dy - size / 2);
    canvas.scale(size);
    final p = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth / size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    switch (this) {
      case sun:
        canvas.drawCircle(const Offset(0.5, 0.5), 0.36, p);
        canvas.drawCircle(
            const Offset(0.5, 0.5),
            0.075,
            Paint()
              ..color = stroke.color
              ..style = PaintingStyle.fill);
      case moon:
        final path = Path()
          ..moveTo(0.56, 0.12)
          ..arcToPoint(const Offset(0.56, 0.88),
              radius: const Radius.circular(0.39), clockwise: false)
          ..arcToPoint(const Offset(0.56, 0.12),
              radius: const Radius.circular(0.50), clockwise: true);
        canvas.drawPath(path, p);
      case mercury:
        canvas.drawCircle(const Offset(0.5, 0.47), 0.20, p);
        canvas.drawLine(const Offset(0.5, 0.67), const Offset(0.5, 0.95), p);
        canvas.drawLine(const Offset(0.36, 0.82), const Offset(0.64, 0.82), p);
        final horns = Path()
          ..moveTo(0.31, 0.08)
          ..arcToPoint(const Offset(0.69, 0.08),
              radius: const Radius.circular(0.20), clockwise: false);
        canvas.drawPath(horns, p);
      case venus:
        canvas.drawCircle(const Offset(0.5, 0.36), 0.23, p);
        canvas.drawLine(const Offset(0.5, 0.59), const Offset(0.5, 0.95), p);
        canvas.drawLine(const Offset(0.33, 0.79), const Offset(0.67, 0.79), p);
      case mars:
        canvas.drawCircle(const Offset(0.41, 0.59), 0.25, p);
        canvas.drawLine(const Offset(0.59, 0.41), const Offset(0.86, 0.14), p);
        canvas.drawLine(const Offset(0.86, 0.14), const Offset(0.62, 0.14), p);
        canvas.drawLine(const Offset(0.86, 0.14), const Offset(0.86, 0.38), p);
      case jupiter:
        final hook = Path()
          ..moveTo(0.24, 0.32)
          ..cubicTo(0.24, 0.06, 0.60, 0.06, 0.60, 0.32)
          ..cubicTo(0.60, 0.48, 0.34, 0.52, 0.20, 0.68)
          ..lineTo(0.82, 0.68);
        canvas.drawPath(hook, p);
        canvas.drawLine(const Offset(0.66, 0.44), const Offset(0.66, 0.95), p);
      case saturn:
        canvas.drawLine(const Offset(0.36, 0.10), const Offset(0.36, 0.88), p);
        canvas.drawLine(const Offset(0.20, 0.27), const Offset(0.52, 0.27), p);
        final bowl = Path()
          ..moveTo(0.36, 0.54)
          ..cubicTo(0.54, 0.36, 0.78, 0.42, 0.74, 0.62)
          ..cubicTo(0.71, 0.75, 0.62, 0.85, 0.57, 0.95);
        canvas.drawPath(bowl, p);
    }
    canvas.restore();
  }
}
