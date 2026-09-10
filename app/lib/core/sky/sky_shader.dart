import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'celestial_scene.dart';
import 'sky_camera.dart';

/// Loads `shaders/sky.frag` once and knows the order of its uniforms.
class SkyShader {
  SkyShader._(this._program, this._weatherProgram, this._cloudTextures);

  final ui.FragmentProgram _program;
  final ui.FragmentProgram? _weatherProgram;
  final List<ui.Image> _cloudTextures;
  ui.FragmentShader? _skyInstance;
  ui.FragmentShader? _weatherInstance;

  bool get hasWeather =>
      _weatherProgram != null && _cloudTextures.length >= 3;

  static Future<SkyShader>? _loading;

  /// Resolves once per process; a failure is remembered as null so the
  /// painter falls back instead of retrying every frame.
  static Future<SkyShader?> load() {
    _loading ??= _loadResources();
    return _loading!.then<SkyShader?>(
      (s) => SkyShader._(s._program, s._weatherProgram, s._cloudTextures),
      onError: (Object e, StackTrace st) {
        debugPrint('sky shader unavailable: $e');
        return null;
      },
    );
  }

  static Future<SkyShader> _loadResources() async {
    final skyProgram = await ui.FragmentProgram.fromAsset('shaders/sky.frag');
    ui.FragmentProgram? weatherProgram;
    final cloudTextures = <ui.Image>[];
    try {
      weatherProgram =
          await ui.FragmentProgram.fromAsset('shaders/weather.frag');
      final textures = await Future.wait([
        for (final name in ['stratus', 'cumulus', 'cirrus']) _loadTexture(name),
      ]);
      cloudTextures.addAll(textures);
    } catch (e) {
      debugPrint('weather shader assets unavailable: $e');
    }
    return SkyShader._(skyProgram, weatherProgram, cloudTextures);
  }

  static Future<ui.Image> _loadTexture(String name) async {
    final data = await rootBundle.load('assets/sky/clouds/$name.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  ui.FragmentShader newShader() => _skyInstance ??= _program.fragmentShader();

  void dispose() {
    _skyInstance?.dispose();
    _weatherInstance?.dispose();
  }

  /// Weather is composited after the catalog so a cloud occludes every
  /// celestial body, including points drawn by Canvas. Clear pays no pass.
  ui.FragmentShader? weatherShader({
    required ResolvedScene scene,
    required SkyCamera camera,
    required double time,
    required double pixelScale,
  }) {
    if (!hasWeather) return null;
    final shader = _weatherInstance ??= _weatherProgram!.fragmentShader();
    final weather = scene.state.weather!;
    var i = 0;
    void f(double value) => shader.setFloat(i++, value);
    f(camera.size.width);
    f(camera.size.height);
    f(camera.principal.dx);
    f(camera.principal.dy);
    f(camera.focal);
    f(camera.azimuthRad);
    f(scene.sunDir.x);
    f(scene.sunDir.y);
    f(scene.sunDir.z);
    f(scene.dayness);
    f(scene.moonIllumination * scene.moonDir.y.clamp(0.0, 1.0));
    f(time);
    f(pixelScale);
    f(weather.cloudCoverage);
    f(weather.cumulus);
    f(weather.rain);
    f(weather.fog);
    f(weather.snow);
    f(weather.cirrus);
    for (var index = 0; index < _cloudTextures.length; index++) {
      shader.setImageSampler(index, _cloudTextures[index]);
    }
    return shader;
  }

  /// Angular radii, radians. The sun is drawn near true size; the moon is
  /// enlarged about 3× so its surface reads on a phone — the one stylisation.
  static const double sunAngularRadius = 0.00465;
  static const double moonAngularRadius = 0.014;

  static void write(
    ui.FragmentShader shader, {
    required ResolvedScene scene,
    required SkyCamera camera,
    required double time,
    double pixelScale = 1.0,
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
    for (final p in s.planets) {
      f(p.dir.x);
      f(p.dir.y);
      f(p.dir.z);
      f(p.brightness * p.visibility);
    }
    f(pixelScale);
  }
}
