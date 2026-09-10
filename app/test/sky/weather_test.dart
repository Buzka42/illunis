import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_camera.dart';
import 'package:illunis/core/sky/sky_painter.dart';
import 'package:illunis/core/sky/sky_shader.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/sky/sky_view.dart';
import 'package:illunis/core/state/sky_state_source.dart';

SkyState state({SkyWeather? weather, double time = 0.5}) => SkyState(
  timeOfDay: time,
  dayOfYear: 252,
  epochDays: epochDaysForDate(2026, 9, 9) - 2 / 24,
  latitudeDeg: 52.23,
  moonPhase: 0.5,
  solarNoon: 0.5234,
  weather: weather,
);

Future<Uint8List> pixels(
  SkyShader shader,
  SkyState input, {
  double time = 0,
  Color? underWeather,
}) async {
  const size = Size(240, 480);
  final scene = CelestialScene.resolve(input);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (underWeather != null) {
    canvas.drawColor(underWeather, BlendMode.src);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader.weatherShader(
          scene: scene,
          camera: SkyCamera(size: size, azimuthRad: scene.trackAzimuthRad),
          time: time,
          pixelScale: 1,
        ),
    );
  } else {
    SkyPainter(
      scene: scene,
      azimuthRad: scene.trackAzimuthRad,
      shader: shader,
      time: time,
      devicePixelRatio: 1,
    ).paint(canvas, size);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(240, 480);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

double difference(Uint8List a, Uint8List b, int fromY, int toY) {
  var sum = 0.0;
  for (var y = fromY; y < toY; y++) {
    for (var x = 0; x < 240; x++) {
      final i = (y * 240 + x) * 4;
      for (var c = 0; c < 3; c++) {
        sum += (a[i + c] - b[i + c]).abs();
      }
    }
  }
  return sum / ((toY - fromY) * 240 * 3);
}

void main() {
  test('weather absence, copying and equality remain distinguishable', () {
    final unknown = state();
    final clear = unknown.copyWith(weather: const SkyWeather.clear());
    expect(unknown.weather, isNull);
    expect(clear, isNot(unknown));
    expect(clear.copyWith().weather, const SkyWeather.clear());
    expect(clear.copyWith(weather: null), unknown);
    final wet = state(weather: WeatherPreset.rain.weather);
    expect(wet.copyWith(), wet);
    expect(wet.copyWith().hashCode, wet.hashCode);
    expect(wet.toString(), contains('rain=0.8'));
    final wisps = wet.copyWith(weather: wet.weather!.copyWith(cirrus: 1));
    expect(wisps, isNot(wet));
    expect(SkyState.lerp(wet, wisps, 0.5).weather!.cirrus, 0.5);
  });

  test(
    'rain to snow blends components and a missing observation fades out',
    () {
      final rain = state(weather: WeatherPreset.rain.weather);
      final snow = state(weather: WeatherPreset.snow.weather);
      final mix = SkyState.lerp(rain, snow, 0.5).weather!;
      expect(mix.rain, closeTo(0.4, 1e-9));
      expect(mix.snow, closeTo(0.4, 1e-9));
      expect(SkyState.lerp(rain, state(), 1).weather, isNull);
      var frame = rain;
      for (var i = 0; i < 1000; i++) {
        frame = SkyState.lerp(frame, state(), 0.03);
      }
      expect(frame.weather, isNull);
    },
  );

  test('debug weather overrides preserve source and reset correctly', () {
    final source = state(weather: WeatherPreset.snow.weather);
    expect(const SkyOverrides().apply(source).weather, source.weather);
    expect(
      const SkyOverrides(
        weatherPreset: WeatherPreset.clear,
      ).apply(source).weather,
      const SkyWeather.clear(),
    );
    final manual = const SkyOverrides(
      weatherPreset: WeatherPreset.rain,
    ).copyWith(weather: const SkyWeather(cloudCoverage: 0.3, fog: 0.8));
    expect(manual.apply(source).weather!.fog, 0.8);
    expect(manual.any, isTrue);
  });

  testWidgets('native shader weather occludes bodies and keeps fog at depth', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final shader = await SkyShader.load();
      expect(
        shader,
        isNotNull,
        reason: 'The production shaders must compile; fallback is not a pass.',
      );
      final plain = await pixels(shader!, state());
      final clear = await pixels(
        shader,
        state(weather: const SkyWeather.clear()),
      );
      expect(clear, orderedEquals(plain));
      final overcast = state(weather: WeatherPreset.overcast.weather);
      final white = await pixels(shader, overcast, underWeather: Colors.white);
      final black = await pixels(shader, overcast, underWeather: Colors.black);
      expect(
        difference(white, black, 0, 268),
        lessThan(0.1),
        reason:
            'An overcast must hide even a white solar disc or catalog point.',
      );
      final fog = await pixels(
        shader,
        state(weather: const SkyWeather(cloudCoverage: 0, fog: 0.9)),
      );
      expect(
        difference(plain, fog, 230, 267),
        greaterThan(difference(plain, fog, 0, 40) * 4),
      );
      expect(
        difference(plain, fog, 410, 470),
        lessThan(1.5),
        reason: 'Near ground remains the matte reading surface.',
      );
      for (final preset in [
        WeatherPreset.cloudy,
        WeatherPreset.cirrus,
        WeatherPreset.rain,
        WeatherPreset.snow,
      ]) {
        final rendered = await pixels(shader, state(weather: preset.weather));
        expect(
          difference(plain, rendered, 0, 267),
          // High ice-cloud wisps intentionally remain much subtler than decks.
          greaterThan(preset == WeatherPreset.cirrus ? 0.5 : 2),
          reason: preset.name,
        );
      }
      final wet = state(weather: WeatherPreset.rain.weather);
      expect(
        difference(
          await pixels(shader, wet),
          await pixels(shader, wet, time: 2),
          0,
          250,
        ),
        greaterThan(0.01),
      );
    });
  });

  testWidgets(
    'weather eases, reduced motion freezes effects, lifecycle pauses sky',
    (tester) async {
      ResolvedScene? scene;
      Widget view(SkyState input) => MediaQuery(
        data: const MediaQueryData(
          size: Size(240, 480),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SkyView(state: input, onScene: (s) => scene = s),
        ),
      );
      await tester.pumpWidget(view(state()));
      await tester.pumpWidget(view(state(weather: WeatherPreset.rain.weather)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scene!.state.weather!.rain, inExclusiveRange(0, 0.8));
      SkyPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SkyPainter>()
          .single;
      expect(painter().time, 0);
      final previous = scene;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(identical(scene, previous), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(identical(scene, previous), isFalse);
      expect(painter().time, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
