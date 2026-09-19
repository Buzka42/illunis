import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/journal/path_events.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/path_event_geometry.dart';
import 'package:illunis/core/sky/sky_camera.dart';
import 'package:illunis/core/sky/sky_state.dart';

void main() {
  const testSize = Size(400, 800);

  SkyState makeState({
    double t = 0.5,
    double day = 80,
    double lat = 52.23,
    double moon = 0.25,
    SkyWeather weather = const SkyWeather.clear(),
  }) => SkyState(
    timeOfDay: t,
    dayOfYear: day,
    epochDays: epochDaysForDate(2026, 1, 1) + (day - 1),
    latitudeDeg: lat,
    moonPhase: moon,
    weather: weather,
  );

  PathEvent makeEvent({
    String id = 'e1',
    PathEventKind kind = PathEventKind.intake,
    DateTime? timestamp,
    Duration? duration,
    double? kcal = 500,
    PathTimestampBasis basis = PathTimestampBasis.logAnchored,
  }) => PathEvent(
    recordId: id,
    civilDay: '2026-03-21',
    kind: kind,
    timestamp: timestamp ?? DateTime(2026, 3, 21, 12, 0),
    timestampBasis: basis,
    duration: duration,
    kcal: kcal,
    provenance: PathEventProvenance.journal,
  );

  group('kcal area-proportional mapping', () {
    test('doubling kcal doubles circle area (area proportional to kcal)', () {
      const policy = PathPolicy(
        baseRadius: 3.0,
        minRadius: 0.5,
        maxRadius: 50.0,
        referenceEnergy: 500.0,
      );

      const kcal1 = 300.0;
      const kcal2 = 600.0; // 2x kcal1

      final r1 = policy.radiusForKcal(kcal1);
      final r2 = policy.radiusForKcal(kcal2);

      final a1 = policy.areaForKcal(kcal1);
      final a2 = policy.areaForKcal(kcal2);

      // Area ratio must equal kcal ratio = 2.0
      expect(a2 / a1, closeTo(2.0, 0.0001));

      // Radius ratio must equal sqrt(2.0) ~= 1.41421356
      expect(r2 / r1, closeTo(math.sqrt(2.0), 0.0001));

      // Quadrupling kcal (4x) quadruples area and doubles radius (2x)
      const kcal4 = 1200.0;
      final r4 = policy.radiusForKcal(kcal4);
      final a4 = policy.areaForKcal(kcal4);

      expect(a4 / a1, closeTo(4.0, 0.0001));
      expect(r4 / r1, closeTo(2.0, 0.0001));
    });

    test('clamping and null/invalid kcal defaults to baseRadius', () {
      const policy = PathPolicy(
        baseRadius: 3.0,
        minRadius: 1.5,
        maxRadius: 10.0,
      );

      // Null or non-positive
      expect(policy.radiusForKcal(null), 3.0);
      expect(policy.radiusForKcal(0), 3.0);
      expect(policy.radiusForKcal(-100), 3.0);
      expect(policy.radiusForKcal(double.nan), 3.0);

      // Lower clamp
      expect(policy.radiusForKcal(5.0), 1.5);

      // Upper clamp
      expect(policy.radiusForKcal(100000.0), 10.0);
    });
  });

  group('known duration controls streak', () {
    test('event with known duration produces continuous streak samples along path', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      final camera = SkyCamera(size: testSize, azimuthRad: scene.sunAzimuthRad);

      final eventWithDuration = makeEvent(
        id: 'run-45m',
        kind: PathEventKind.burn,
        timestamp: DateTime(2026, 3, 21, 12, 0),
        duration: const Duration(minutes: 45),
        kcal: 400,
      );

      final cache = PathEventGeometryPipeline.compute(
        events: [eventWithDuration],
        scene: scene,
        camera: camera,
        policy: const PathPolicy(sampleStepMinutes: 3.0),
      );

      final pe = cache.projectedEvents.single;
      // 45 min / 3 min step = 15 segments -> 16 samples
      expect(pe.streakSamples.length, greaterThanOrEqualTo(15));

      // Samples start at anchor time 12:00 (t=0.5) and end at 12:45 (t = 0.5 + 45/(24*60) = 0.53125)
      expect(pe.streakSamples.first.timeOfDay, closeTo(0.5, 0.0001));
      expect(pe.streakSamples.last.timeOfDay, closeTo(0.53125, 0.0001));

      // Reuses scene.sunDirectionAt: each sample's direction matches sunDirectionAt(t)
      for (final sample in pe.streakSamples) {
        final expectedDir = scene.sunDirectionAt(sample.timeOfDay % 1.0);
        expect(sample.direction.x, closeTo(expectedDir.x, 0.0001));
        expect(sample.direction.y, closeTo(expectedDir.y, 0.0001));
        expect(sample.direction.z, closeTo(expectedDir.z, 0.0001));
      }
    });

    test('event with unknown duration produces NO streak samples (length never invented)', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      final camera = SkyCamera(size: testSize, azimuthRad: scene.sunAzimuthRad);

      final eventUnknownDuration = makeEvent(
        id: 'meal-instant',
        kind: PathEventKind.intake,
        timestamp: DateTime(2026, 3, 21, 12, 0),
        duration: null, // Unknown duration!
        kcal: 600,
      );

      final cache = PathEventGeometryPipeline.compute(
        events: [eventUnknownDuration],
        scene: scene,
        camera: camera,
      );

      final pe = cache.projectedEvents.single;
      expect(pe.streakSamples, isEmpty, reason: 'Unknown duration must have empty streak samples');
      expect(pe.anchorScreenPoint, isNotNull);
    });
  });

  group('clipping, offscreen, midnight, coincident, moonless, yaw', () {
    test('clipping: streak extending outside viewport is flagged as isClipped', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      // Point camera directly at the sun
      final camera = SkyCamera(size: const Size(200, 200), azimuthRad: scene.sunAzimuthRad);

      // An activity lasting 8 hours will travel well across the sky and out of the small 200x200 camera
      final longEvent = makeEvent(
        id: 'long-trek',
        kind: PathEventKind.burn,
        timestamp: DateTime(2026, 3, 21, 12, 0),
        duration: const Duration(hours: 8),
        kcal: 2000,
      );

      final cache = PathEventGeometryPipeline.compute(
        events: [longEvent],
        scene: scene,
        camera: camera,
      );

      final pe = cache.projectedEvents.single;
      expect(pe.isClipped, isTrue, reason: 'Streak crossing outside viewport must be flagged isClipped');
    });

    test('offscreen: event behind camera is flagged isOffscreen with isAnchorVisible=false', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      // Point camera opposite the sun (180 deg away)
      final oppositeAzimuth = wrapAngle(scene.sunAzimuthRad + math.pi);
      final camera = SkyCamera(size: testSize, azimuthRad: oppositeAzimuth);

      final noonEvent = makeEvent(
        id: 'noon-behind',
        timestamp: DateTime(2026, 3, 21, 12, 0),
        duration: null,
      );

      final cache = PathEventGeometryPipeline.compute(
        events: [noonEvent],
        scene: scene,
        camera: camera,
      );

      final pe = cache.projectedEvents.single;
      expect(pe.isAnchorVisible, isFalse);
      expect(pe.isOffscreen, isTrue);
    });

    test('midnight: event spanning midnight wraps day fraction smoothly', () {
      final state = makeState(t: 0.98); // 23:31
      final scene = CelestialScene.resolve(state);
      final camera = SkyCamera(size: testSize, azimuthRad: 0);

      // Event starting at 23:30 and running for 60 minutes into the next day (00:30)
      final midnightEvent = makeEvent(
        id: 'midnight-walk',
        kind: PathEventKind.burn,
        timestamp: DateTime(2026, 3, 21, 23, 30),
        duration: const Duration(minutes: 60),
      );

      final cache = PathEventGeometryPipeline.compute(
        events: [midnightEvent],
        scene: scene,
        camera: camera,
        policy: const PathPolicy(sampleStepMinutes: 5.0),
      );

      final pe = cache.projectedEvents.single;
      expect(pe.streakSamples, isNotEmpty);

      // First sample before midnight: t ~ 23.5/24 = 0.979166
      expect(pe.streakSamples.first.timeOfDay, closeTo(23.5 / 24, 0.001));

      // Last sample after midnight: t > 1.0 (wrapped in daytime calculation)
      expect(pe.streakSamples.last.timeOfDay, greaterThan(1.0));
      expect(pe.streakSamples.last.timeOfDay % 1.0, closeTo(0.5 / 24, 0.001));
    });

    test('coincident: multiple events at identical timestamp are fanned perpendicularly', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      final camera = SkyCamera(size: testSize, azimuthRad: scene.sunAzimuthRad);

      final sharedTime = DateTime(2026, 3, 21, 12, 0);
      final ev1 = makeEvent(id: 'c1', timestamp: sharedTime, kcal: 400);
      final ev2 = makeEvent(id: 'c2', timestamp: sharedTime, kcal: 600);
      final ev3 = makeEvent(id: 'c3', timestamp: sharedTime, kcal: 250);

      final cache = PathEventGeometryPipeline.compute(
        events: [ev1, ev2, ev3],
        scene: scene,
        camera: camera,
        policy: const PathPolicy(coincidentSpacingDp: 8.0),
      );

      expect(cache.projectedEvents, hasLength(3));

      for (var i = 0; i < 3; i++) {
        final pe = cache.projectedEvents[i];
        expect(pe.isCoincident, isTrue);
        expect(pe.coincidentCount, 3);
        expect(pe.coincidentIndex, i);
      }

      // The middle event (index 1) has zero shift factor: (1 - (3-1)/2 = 0)
      expect(cache.projectedEvents[1].coincidentOffset, Offset.zero);

      // Event 0 and Event 2 have opposite non-zero offsets
      final off0 = cache.projectedEvents[0].coincidentOffset;
      final off2 = cache.projectedEvents[2].coincidentOffset;
      expect(off0.distance, greaterThan(0.0));
      expect(off2.distance, greaterThan(0.0));
      expect(off0.dx, closeTo(-off2.dx, 0.001));
      expect(off0.dy, closeTo(-off2.dy, 0.001));

      // Effective screen points are distinct (non-colliding)
      final p0 = cache.projectedEvents[0].effectiveScreenPoint!;
      final p1 = cache.projectedEvents[1].effectiveScreenPoint!;
      final p2 = cache.projectedEvents[2].effectiveScreenPoint!;
      expect((p0 - p1).distance, greaterThan(3.0));
      expect((p2 - p1).distance, greaterThan(3.0));
    });

    test('moonless: new moon is detected and lunar tracking respects policy', () {
      // Moon phase 0.0 = new moon, completely dark
      final moonlessState = makeState(t: 0.1, moon: 0.0);
      final scene = CelestialScene.resolve(moonlessState);
      final camera = SkyCamera(size: testSize, azimuthRad: 0);

      expect(isMoonlessScene(scene), isTrue);

      final nightEvent = makeEvent(
        id: 'night-snack',
        timestamp: DateTime(2026, 3, 21, 2, 0),
      );

      final cache = PathEventGeometryPipeline.compute(
        events: [nightEvent],
        scene: scene,
        camera: camera,
        policy: const PathPolicy(track: CelestialTrack.autoActive),
      );

      expect(cache.isMoonless, isTrue);
    });

    test('yaw: camera azimuth rotation shifts screen projection conformally', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);

      final noonEvent = makeEvent(
        id: 'noon-yaw',
        timestamp: DateTime(2026, 3, 21, 12, 0),
      );

      // Facing the sun directly: principal point dx should be size.width / 2 = 200
      final camFacing = SkyCamera(size: testSize, azimuthRad: scene.sunAzimuthRad);
      final cacheFacing = PathEventGeometryPipeline.compute(
        events: [noonEvent],
        scene: scene,
        camera: camFacing,
      );
      final ptFacing = cacheFacing.projectedEvents.single.anchorScreenPoint!;
      expect(ptFacing.dx, closeTo(testSize.width / 2, 1.0));

      // Rotate camera yaw by +15 degrees
      final camRotated = SkyCamera(
        size: testSize,
        azimuthRad: wrapAngle(scene.sunAzimuthRad + 15 * degToRad),
      );
      final cacheRotated = PathEventGeometryPipeline.compute(
        events: [noonEvent],
        scene: scene,
        camera: camRotated,
      );
      final ptRotated = cacheRotated.projectedEvents.single.anchorScreenPoint!;

      // Conformal stereographic shift to the left
      expect(ptRotated.dx, lessThan(ptFacing.dx));

      // But the world 3D celestial direction is completely invariant to camera yaw!
      expect(
        cacheFacing.projectedEvents.single.anchorDirection.x,
        closeTo(cacheRotated.projectedEvents.single.anchorDirection.x, 0.0001),
      );
      expect(
        cacheFacing.projectedEvents.single.anchorDirection.y,
        closeTo(cacheRotated.projectedEvents.single.anchorDirection.y, 0.0001),
      );
    });
  });

  group('cache prep outside paint and no new ticker', () {
    test('cache contains all precomputed coordinates allowing paint with 0 projections', () {
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      final camera = SkyCamera(size: testSize, azimuthRad: scene.sunAzimuthRad);

      final events = [
        makeEvent(
          id: 'meal-1',
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 12, 0),
          kcal: 600,
        ),
        makeEvent(
          id: 'burn-1',
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 12, 30),
          duration: const Duration(minutes: 30),
          kcal: 250,
        ),
      ];

      // Step 1: Precompute cache OUTSIDE of paint
      final cache = PathEventGeometryPipeline.compute(
        events: events,
        scene: scene,
        camera: camera,
      );

      expect(cache.projectedEvents, hasLength(2));
      final pe0 = cache.projectedEvents[0];
      final pe1 = cache.projectedEvents[1];

      expect(pe0.effectiveScreenPoint, isNotNull);
      expect(pe1.streakSamples, isNotEmpty);

      // Step 2: CustomPainter paints directly from cache with zero projections
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Direct paint simulation
      for (final pe in cache.projectedEvents) {
        if (pe.effectiveScreenPoint != null) {
          canvas.drawCircle(pe.effectiveScreenPoint!, pe.radius, Paint());
        }
        if (pe.streakSamples.isNotEmpty) {
          final p = Path();
          var first = true;
          for (final s in pe.streakSamples) {
            if (s.screenPoint != null) {
              if (first) {
                p.moveTo(s.screenPoint!.dx, s.screenPoint!.dy);
                first = false;
              } else {
                p.lineTo(s.screenPoint!.dx, s.screenPoint!.dy);
              }
            }
          }
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke);
        }
      }

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('no new ticker instantiated by geometry pipeline or preview', (
      tester,
    ) async {
      // Pumping a widget using PathEventGeometryPipeline must not register or require any Ticker
      final state = makeState(t: 0.5);
      final scene = CelestialScene.resolve(state);
      final camera = SkyCamera(size: testSize, azimuthRad: scene.sunAzimuthRad);
      final cache = PathEventGeometryPipeline.compute(
        events: [
          makeEvent(
            id: 'e1',
            duration: const Duration(minutes: 30),
            kcal: 400,
          ),
        ],
        scene: scene,
        camera: camera,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 150,
                child: CustomPaint(
                  painter: _TestCachePainter(cache),
                ),
              ),
            ),
          ),
        ),
      );

      // Zero active or binding tickers
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

class _TestCachePainter extends CustomPainter {
  const _TestCachePainter(this.cache);
  final PathEventGeometryCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    for (final pe in cache.projectedEvents) {
      if (pe.effectiveScreenPoint != null) {
        canvas.drawCircle(pe.effectiveScreenPoint!, pe.radius, Paint());
      }
    }
  }

  @override
  bool shouldRepaint(_TestCachePainter oldDelegate) =>
      oldDelegate.cache != cache;
}
