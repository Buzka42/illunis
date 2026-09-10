import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_painter.dart';
import 'package:illunis/core/sky/sky_shader.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/state/sky_state_source.dart';

void main() {
  const base = SkyState(
    timeOfDay: 0.5,
    dayOfYear: 252,
    epochDays: 9747.4166666667,
    latitudeDeg: 52.23,
    moonPhase: 0.5,
    solarNoon: 0.5234,
  );
  SkyState dusk(double altitude) {
    final scene = CelestialScene.resolve(base);
    final angle = hourAngleAtAltitude(
      scene.sunDeclinationRad,
      scene.latitudeRad,
      altitude * degToRad,
    )!;
    return base.copyWith(timeOfDay: base.solarNoon + angle / (2 * math.pi));
  }

  final groups = <String, List<SkyState>>{
    'clear_twilight': [base, dusk(1), dusk(-3), dusk(-9), dusk(-15)],
    'weather': [
      for (final p in [
        WeatherPreset.cloudy,
        WeatherPreset.cirrus,
        WeatherPreset.overcast,
        WeatherPreset.rain,
        WeatherPreset.fog,
        WeatherPreset.snow,
      ])
        base.copyWith(weather: p.weather),
    ],
    'moon_overcast': [
      base.copyWith(timeOfDay: 0.04),
      base.copyWith(timeOfDay: 0.04, moonPhase: 0.25),
      base.copyWith(timeOfDay: 0.04, weather: WeatherPreset.overcast.weather),
    ],
  };
  for (final entry in groups.entries) {
    testWidgets('${entry.key} native shader reference', (tester) async {
      final shader = await tester.runAsync(SkyShader.load);
      expect(shader, isNotNull);
      final size = Size(200.0 * entry.value.length, 400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('gallery'),
            child: Row(
              children: [
                for (final state in entry.value)
                  SizedBox(
                    width: 200,
                    height: 400,
                    child: CustomPaint(
                      painter: SkyPainter(
                        scene: CelestialScene.resolve(state),
                        azimuthRad: CelestialScene.resolve(
                          state,
                        ).trackAzimuthRad,
                        shader: shader,
                        time: 0,
                        devicePixelRatio: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('gallery')),
        matchesGoldenFile('goldens/${entry.key}.png'),
      );
    });
  }
}
