import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/journal/path_events.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/path_event_geometry.dart';
import 'package:illunis/core/sky/sky_camera.dart';
import 'package:illunis/features/debug/path_event_fixtures.dart';
import 'package:illunis/features/debug/sky_debug_sheet.dart';

void main() {
  group('PathEventFixture suite', () {
    test('all 7 fixtures resolve valid geometry cache without error', () {
      final fixtures = PathEventFixture.getAll();
      expect(fixtures, hasLength(7));

      const size = Size(320, 160);

      for (final fix in fixtures) {
        final scene = CelestialScene.resolve(fix.state);
        final cam = SkyCamera(size: size, azimuthRad: scene.trackAzimuthRad);

        final cache = PathEventGeometryPipeline.compute(
          events: fix.events,
          scene: scene,
          camera: cam,
        );

        expect(
          cache.projectedEvents,
          hasLength(fix.events.length),
          reason: 'Fixture ${fix.id.name} should project all events',
        );

        for (final pe in cache.projectedEvents) {
          expect(pe.radius, greaterThanOrEqualTo(1.5));
          expect(pe.honestyLabel, isNotEmpty);
        }
      }
    });

    test('dawn fixture: sunrise time with breakfast & morning run', () {
      final dawn = PathEventFixture.get(PathEventFixtureId.dawn);
      expect(dawn.state.timeOfDay, closeTo(0.26, 0.01));
      expect(dawn.events, hasLength(2));

      final breakfast = dawn.events[0];
      final run = dawn.events[1];

      expect(breakfast.kind, PathEventKind.intake);
      expect(breakfast.duration, isNull); // unknown duration never invented
      expect(breakfast.isLogAnchored, isTrue);

      expect(run.kind, PathEventKind.burn);
      expect(run.duration, const Duration(minutes: 35));
    });

    test('noon fixture: midday solar culmination with lunch & walk', () {
      final noon = PathEventFixture.get(PathEventFixtureId.noon);
      expect(noon.state.timeOfDay, 0.5);
      expect(noon.events, hasLength(2));

      final lunch = noon.events[0];
      final walk = noon.events[1];

      expect(lunch.kcal, 750);
      expect(lunch.duration, isNull);
      expect(walk.duration, const Duration(minutes: 40));
    });

    test('dusk fixture: sunset twilight with dinner & evening ride', () {
      final dusk = PathEventFixture.get(PathEventFixtureId.dusk);
      expect(dusk.state.timeOfDay, closeTo(0.765, 0.01));
      expect(dusk.events, hasLength(2));

      final dinner = dusk.events[0];
      final ride = dusk.events[1];

      expect(dinner.kcal, 850);
      expect(ride.duration, const Duration(minutes: 45));
    });

    test('moonlit fixture: bright moon night with late stroll', () {
      final moonlit = PathEventFixture.get(PathEventFixtureId.moonlit);
      expect(moonlit.state.timeOfDay, greaterThan(0.9));
      expect(moonlit.state.moonPhase, 0.5); // full/half bright moon

      final scene = CelestialScene.resolve(moonlit.state);
      expect(isMoonlessScene(scene), isFalse);
    });

    test('moonless fixture: new moon (0% illumination) dark night', () {
      final moonless = PathEventFixture.get(PathEventFixtureId.moonless);
      expect(moonless.state.moonPhase, 0.0);

      final scene = CelestialScene.resolve(moonless.state);
      expect(isMoonlessScene(scene), isTrue);
    });

    test('overcast fixture: 100% cloud coverage with indoor training', () {
      final overcast = PathEventFixture.get(PathEventFixtureId.overcast);
      expect(overcast.state.weather?.cloudCoverage, 1.0);
      expect(overcast.events, hasLength(2));
    });

    test('dense overlaps fixture: multiple coincident events at identical instant', () {
      final dense = PathEventFixture.get(PathEventFixtureId.denseOverlaps);
      expect(dense.events, hasLength(5));

      final sharedInstant = dense.events.first.timestamp;
      for (final ev in dense.events) {
        expect(ev.timestamp, sharedInstant);
      }

      final scene = CelestialScene.resolve(dense.state);
      final cam = SkyCamera(
        size: const Size(400, 800),
        azimuthRad: scene.sunAzimuthRad,
      );

      final cache = PathEventGeometryPipeline.compute(
        events: dense.events,
        scene: scene,
        camera: cam,
      );

      // All 5 events must be flagged as coincident
      for (final pe in cache.projectedEvents) {
        expect(pe.isCoincident, isTrue);
        expect(pe.coincidentCount, 5);
      }

      // Check non-zero offsets spread across normal
      final offsets = cache.projectedEvents.map((e) => e.coincidentOffset).toList();
      final distinctOffsets = offsets.toSet();
      expect(distinctOffsets.length, 5, reason: 'All 5 events must have unique displaced offsets');
    });
  });

  group('SkyDebugSheet fixture interaction', () {
    testWidgets('tapping fixture button displays fixture preview card', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showSkyDebugSheet(context),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap open
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      // Verify debug sheet is open
      expect(find.text('SKY · DEBUG'), findsOneWidget);
      expect(find.text('PATH EVENT FIXTURES (A2)'), findsOneWidget);

      // Tap 'DENSE OVERLAPS' fixture button
      await tester.tap(find.text('DENSE OVERLAPS'));
      await tester.pumpAndSettle();

      // Fixture preview card should appear
      expect(find.text('DENSE OVERLAPS'), findsWidgets);
      expect(
        find.textContaining('Multiple coincident events at identical instant'),
        findsOneWidget,
      );
      expect(
        find.textContaining('5 events'),
        findsOneWidget,
      );
      expect(
        find.textContaining('[Log-anchored]'),
        findsWidgets,
      );

      // Tap 'DAWN' fixture button
      await tester.tap(find.text('DAWN'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Sunrise with breakfast & morning run'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 events'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
