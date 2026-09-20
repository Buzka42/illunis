import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/sky/celestial_math.dart';
import 'package:illunis/core/sky/sky_camera.dart';
import 'package:illunis/core/theme/typography.dart';
import 'package:illunis/features/settings/quick_guide.dart';

/// P2 FIXTURES ONLY. No production sky changes.
///
/// Edge-bearing / below-horizon / bright-noon / crowded-leader fixtures for
/// the sky overlay painter + sky-letter surface, pinning the vocabulary the
/// production fix must use: offscreen (projection returns null) vs clipped
/// (projected, outside bounds) are different states and must read differently.
void main() {
  Size phone() => const Size(360, 740);

  group('p2 sky fixtures: projection states', () {
    test('edge-bearing: body at the frame edge still projects', () {
      final cam = SkyCamera(size: phone(), azimuthRad: 0);
      // 80° off-axis at the horizon: stereographic keeps it projectable.
      final edge = directionFromAltAz(5 * degToRad, 80 * degToRad);
      final p = cam.project(edge);
      expect(p, isNotNull);
    });

    test('offscreen vs clipped are distinct states', () {
      final cam = SkyCamera(size: phone(), azimuthRad: 0);
      // Behind the camera: no useful projection -> null (OFFSCREEN).
      final behind = directionFromAltAz(10 * degToRad, 180 * degToRad);
      expect(cam.project(behind), isNull);
      // Ahead but far off-axis: projects outside bounds (CLIPPED, not gone).
      final farSide = directionFromAltAz(2 * degToRad, 120 * degToRad);
      final p = cam.project(farSide);
      if (p == null) {
        // Stereographic null past the fold: still OFFSCREEN, never clipped.
        expect(cam.project(behind), isNull);
      } else {
        expect(cam.contains(p), isFalse);
      }
    });

    test('below-horizon: negative altitude projects under the horizon line', () {
      final cam = SkyCamera(size: phone(), azimuthRad: 0);
      final below = directionFromAltAz(-8 * degToRad, 0);
      final p = cam.project(below);
      expect(p, isNotNull);
      expect(p!.dy, greaterThan(cam.principal.dy));
    });

    test('bright-noon: overhead sun projects above the principal point', () {
      final cam = SkyCamera(size: phone(), azimuthRad: 0);
      final noon = directionFromAltAz(70 * degToRad, 0.5 * degToRad);
      final p = cam.project(noon);
      expect(p, isNotNull);
      expect(p!.dy, lessThan(cam.principal.dy));
    });

    test('crowded-leader: two close bodies need stacked lanes, not overlap', () {
      final cam = SkyCamera(size: phone(), azimuthRad: 0);
      final a = cam.project(directionFromAltAz(30 * degToRad, 2 * degToRad));
      final b = cam.project(directionFromAltAz(31 * degToRad, 3 * degToRad));
      expect(a, isNotNull);
      expect(b, isNotNull);
      // Fixture geometry: within one readout height -> production must stack.
      expect((a!.dy - b!.dy).abs(), lessThan(25));
    });
  });

  group('p2 sky fixtures: font-family check before prose-leak claims', () {
    test('instrument voice is JetBrains Mono; prose voice is Inter', () {
      expect(Type.mono, 'JetBrains Mono');
      expect(Type.text, 'Inter');
      // Overlay painter mono constant matches the instrument family.
      expect(Type.mono, contains('JetBrains'));
    });

    test('sky-letter prose renders in the text family, not mono', () {
      // Sky letters are sentences (prose surface): they must use
      // Type.text. This pins the family BEFORE any prose-leak claim against
      // the overlay painter (which is mono by design).
      final prose = const TextStyle(fontFamily: Type.text, fontSize: 14);
      expect(prose.fontFamily, 'Inter');
      expect(prose.fontFamily, isNot(Type.mono));
    });
  });

  group('p2 sky fixtures: source-label explanations live in guide/settings', () {
    test('quick guide entry point exists for source-label legend', () {
      expect(showQuickGuide, isNotNull);
    });

    testWidgets('guide legend text is present and readable', (tester) async {
      final store = AppStore.memory();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: illunisOverrides(store),
          child: MaterialApp(
            home: Scaffold(
              body: TextButton(
                onPressed: () => showQuickGuide(
                  tester.element(find.byType(TextButton)),
                ),
                child: const Text('GUIDE'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('GUIDE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('QUICK GUIDE'), findsOneWidget);
      // Legend lives on the RECORD page: the continuation cue advances it.
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('JNL means journal'), findsOneWidget);
      expect(find.textContaining('HC means Health Connect'), findsOneWidget);
      expect(find.textContaining('RULE means'), findsOneWidget);
    });
  });
}
