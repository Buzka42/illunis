import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'celestial_scene.dart';
import 'sky_camera.dart';

/// Loads `shaders/sky.frag` once and knows the order of its uniforms.
class SkyShader {
  SkyShader._(this._program);

  final ui.FragmentProgram _program;

  static Future<SkyShader>? _loading;

  /// Resolves once per process; a failure is remembered as null so the
  /// painter falls back instead of retrying every frame.
  static Future<SkyShader?> load() {
    _loading ??= ui.FragmentProgram.fromAsset(
      'shaders/sky.frag',
    ).then(SkyShader._);
    return _loading!.then<SkyShader?>(
      (s) => s,
      onError: (Object e, StackTrace st) {
        debugPrint('sky shader unavailable: $e');
        return null;
      },
    );
  }

  ui.FragmentShader newShader() => _program.fragmentShader();

  /// Angular radii, radians. The sun is drawn near true size; the moon is
  /// enlarged about 3× so its surface reads on a phone — the one stylisation.
  static const double sunAngularRadius = 0.0095;
  static const double moonAngularRadius = 0.026;

  static void write(
    ui.FragmentShader shader, {
    required ResolvedScene scene,
    required SkyCamera camera,
    required double time,
  }) {
    final s = scene;
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    f(camera.size.width);
    f(camera.size.height);
    f(camera.principal.dx);
    f(camera.principal.dy);
    f(camera.focal);
    f(camera.azimuthRad);
    f(s.sunDir.x);
    f(s.sunDir.y);
    f(s.sunDir.z);
    f(s.moonDir.x);
    f(s.moonDir.y);
    f(s.moonDir.z);
    f(s.siderealRad);
    f(s.latitudeRad);
    f(s.turbidity);
    f(s.mieScale);
    f(s.exposure);
    f(s.stillness);
    f(time);
    f(moonAngularRadius);
    f(sunAngularRadius);
    f(s.moonIllumination);
    f(s.dayness);
  }
}
