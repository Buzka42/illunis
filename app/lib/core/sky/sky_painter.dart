import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'celestial_scene.dart';
import 'sky_camera.dart';
import 'sky_shader.dart';
import 'star_field.dart';

/// Native-resolution atmosphere, then catalog points. No intermediate
/// image: limbs, grain and gradients are resolved at the display's density.
class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.scene,
    required this.azimuthRad,
    required this.shader,
    required this.time,
    required this.devicePixelRatio,
  });

  final ResolvedScene scene;
  final double azimuthRad;
  final SkyShader? shader;
  final double time;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 8) return;
    final s = shader;
    if (s == null) {
      _paintFallback(canvas, size);
      paintCatalogStars(
        canvas,
        scene: scene,
        camera: SkyCamera(size: size, azimuthRad: azimuthRad),
        time: time,
      );
      _paintFallbackWeather(canvas, size);
      return;
    }
    final camera = SkyCamera(size: size, azimuthRad: azimuthRad);
    final fs = s.newShader();
    SkyShader.write(
      fs,
      scene: scene,
      camera: camera,
      time: time,
      pixelScale: devicePixelRatio,
    );
    final weather = scene.state.weather;
    final closedSky = weather != null && weather.cloudCoverage == 1;
    if (closedSky) {
      // The weather pass is exactly opaque above the horizon at coverage 1.
      // Keep the ground's lighting, but do not shade invisible bodies/stars.
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(0, camera.principal.dy, size.width, size.height),
      );
      canvas.drawRect(Offset.zero & size, Paint()..shader = fs);
      canvas.restore();
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..shader = fs);
      paintCatalogStars(canvas, scene: scene, camera: camera, time: time);
    }
    if (weather != null && !weather.isClear) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = s.weatherShader(
            scene: scene,
            camera: camera,
            time: time,
            pixelScale: devicePixelRatio,
          ),
      );
    }
  }

  void _paintFallbackWeather(Canvas canvas, Size size) {
    final weather = scene.state.weather;
    if (weather == null || weather.isClear) return;
    final horizon = size.height * kHorizonFraction;
    final cloud = Color.lerp(
      const Color(0xFF111723),
      const Color(0xFF9CA6B3),
      scene.dayness,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()..color = cloud.withValues(alpha: weather.cloudCoverage),
    );
    if (weather.fog > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, horizon),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, horizon),
            [
              cloud.withValues(alpha: 0),
              cloud.withValues(alpha: weather.fog * 0.9),
            ],
            [0.55, 1],
          ),
      );
    }
  }

  /// Before the program is compiled, or on a GPU that refuses it: the same
  /// composition in plain gradients, so nothing is ever black.
  void _paintFallback(Canvas canvas, Size size) {
    final d = scene.dayness;
    final horizon = size.height * kHorizonFraction;
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
