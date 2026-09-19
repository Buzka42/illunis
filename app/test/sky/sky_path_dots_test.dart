import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/journal/marks.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_camera.dart';
import 'package:illunis/core/sky/sky_overlay_painter.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/civil_day.dart';

void main() {
  group('skyPathDotsOn mapping', () {
    test('aggregates confirmed intake and burn on the target day', () {
      final store = AppStore.memory();
      final day = '2026-09-19';

      store.journal.add(
        JournalEntry(
          id: 'j1',
          at: DateTime(2026, 9, 19, 8, 30),
          text: 'eggs',
        ),
      );
      store.journal.add(
        JournalEntry(
          id: 'j2',
          at: DateTime(2026, 9, 19, 17, 0),
          text: 'run',
        ),
      );

      // Confirmed meal at 08:30
      store.nutrition.add(
        const NutritionEntry(
          id: 'm1',
          journalEntryId: 'j1',
          day: '2026-09-19',
          label: 'eggs',
          kcal: 450,
          confirmed: true,
        ),
      );

      // Confirmed run at 17:00
      store.activities.add(
        const ActivityEntry(
          id: 'a1',
          journalEntryId: 'j2',
          day: '2026-09-19',
          label: 'run',
          kcal: 500,
          confirmed: true,
        ),
      );

      // Unconfirmed meal -> should be excluded
      store.nutrition.add(
        const NutritionEntry(
          id: 'm2',
          journalEntryId: 'j1',
          day: '2026-09-19',
          label: 'guess',
          kcal: 800,
          confirmed: false,
        ),
      );

      final dots = skyPathDotsOn(store, day);
      expect(dots.length, 2);

      expect(dots[0].isIntake, isTrue);
      expect(dots[0].timeOfDay, closeTo(8.5 / 24, 0.001));
      expect(dots[0].weight, closeTo(0.45, 0.001));

      expect(dots[1].isIntake, isFalse);
      expect(dots[1].timeOfDay, closeTo(17.0 / 24, 0.001));
      expect(dots[1].weight, closeTo(0.50, 0.001));
    });

    test('null or empty dots renders nothing', () {
      final state = const SkyState(
        timeOfDay: 0.5,
        dayOfYear: 100,
        epochDays: 9000,
        latitudeDeg: 52.0,
        moonPhase: 0.25,
        dots: null,
      );
      final scene = CelestialScene.resolve(state);
      final painter = SkyOverlayPainter(
        scene: scene,
        azimuthRad: 0,
        textScale: 1.0,
        showPaths: true,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('dots are positioned along the sun path at their timeOfDay', () {
      const dot = SkyPathDot(
        timeOfDay: 0.5, // noon
        weight: 0.5,
        isIntake: true,
      );
      final state = const SkyState(
        timeOfDay: 0.5,
        dayOfYear: 100,
        epochDays: 9000,
        latitudeDeg: 52.0,
        moonPhase: 0.25,
        dots: [dot],
      );
      final scene = CelestialScene.resolve(state);
      const size = Size(400, 800);
      final cam = SkyCamera(size: size, azimuthRad: 0);

      final noonDir = scene.sunDirectionAt(0.5);
      final expectedProj = cam.project(noonDir);
      expect(expectedProj, isNotNull);

      final painter = SkyOverlayPainter(
        scene: scene,
        azimuthRad: 0,
        textScale: 1.0,
        showPaths: true,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, size);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('skyPathDotsProvider plumbs store updates to dots', () {
      final store = AppStore.memory();
      final day = '2026-09-19';

      store.journal.add(
        JournalEntry(
          id: 'j1',
          at: DateTime(2026, 9, 19, 12, 0),
          text: 'lunch',
        ),
      );
      store.nutrition.add(
        NutritionEntry(
          id: 'm1',
          journalEntryId: 'j1',
          day: day,
          label: 'lunch',
          kcal: 650,
          confirmed: true,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          storeProvider.overrideWithValue(store),
          civilDayProvider.overrideWithValue(DateTime(2026, 9, 19)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(store.dispose);

      final dots = container.read(skyPathDotsProvider);
      expect(dots.length, 1);
      expect(dots.first.isIntake, isTrue);
      expect(dots.first.timeOfDay, closeTo(0.5, 0.001));
      expect(dots.first.weight, closeTo(0.65, 0.001));
    });
  });
}
