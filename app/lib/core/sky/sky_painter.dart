import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'celestial_scene.dart';
import 'sky_camera.dart';
import 'sky_shader.dart';

/// Paints the shader sky, rendered at a reduced resolution and upscaled.
///
/// A full-screen fragment program at native density is the one thing that
/// can miss 60 fps on a mid-range phone. The picture is recorded at
/// [scale] and resolved with `toImageSync` (GPU-resident, no readback), then
/// stretched with linear filtering; the atmosphere has no hard edges to
/// betray it, and the sun and moon limbs are anti-aliased in the shader in
/// target pixels so they stay soft rather than jagged.
class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.scene,
    required this.azimuthRad,
    required this.shader,
    required this.time,
    required this.devicePixelRatio,
    this.scale = 0.7,
  });

  final ResolvedScene scene;
  final double azimuthRad;
  final SkyShader? shader;
  final double time;
  final double devicePixelRatio;
  final double scale;

  static ui.Image? _lastImage;

  @override
  void paint(Canvas canvas, Size size) {
    final s = shader;
    if (s == null) {
      _paintFallback(canvas, size);
      return;
    }
    final camera = SkyCamera(size: size, azimuthRad: azimuthRad);
    final w = math.max(1, (size.width * devicePixelRatio * scale).round());
    final h = math.max(1, (size.height * devicePixelRatio * scale).round());
    final target = Size(w.toDouble(), h.toDouble());
    // Camera in target pixels: same angles, scaled principal point and focal.
    final targetCamera = SkyCamera(
      size: target,
      azimuthRad: azimuthRad,
      horizonFraction: camera.horizonFraction,
      topAltitudeDeg: camera.topAltitudeDeg,
    );

    final fs = s.newShader();
    SkyShader.write(fs, scene: scene, camera: targetCamera, time: time);
    final paint = Paint()..shader = fs;

    ui.Image? image;
    try {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.drawRect(Offset.zero & target, paint);
      final picture = recorder.endRecording();
      image = picture.toImageSync(w, h);
      picture.dispose();
    } catch (_) {
      image = null;
    }

    if (image == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    canvas.drawImageRect(
      image,
      Offset.zero & target,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    _lastImage?.dispose();
    _lastImage = image;
  }

  /// Before the program is compiled, or on a GPU that refuses it: the same
  /// composition in plain gradients, so nothing is ever black.
  void _paintFallback(Canvas canvas, Size size) {
    final d = scene.dayness;
    final horizon = size.height * 0.64;
    final zenith = Color.lerp(
      const Color(0xFF060A16),
      const Color(0xFF3B78C9),
      d,
    )!;
    final low = Color.lerp(
      const Color(0xFF0B1224),
      const Color(0xFFB7CDE8),
      d,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon), [
          zenith,
          low,
        ]),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()..color = const Color(0xFF0A0B0E),
    );
  }

  @override
  bool shouldRepaint(SkyPainter old) => true;
}
