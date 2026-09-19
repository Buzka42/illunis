import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/sky_state_source.dart';
import 'package:illunis/features/dashboard/dashboard_page.dart';
import 'package:illunis/main.dart';

const _base = SkyState(
  timeOfDay: 0.5,
  dayOfYear: 252,
  epochDays: 9747.4,
  latitudeDeg: 52.23,
  moonPhase: 0.25,
);

void main() {
  testWidgets('dashboard has no VOL / LOAD / 1RM strength tiles', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: illunisOverrides(AppStore.memory()),
    );
    final scene = ValueNotifier<ResolvedScene?>(CelestialScene.resolve(_base));
    addTearDown(scene.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: IllunisApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => DashboardPage(
                scene: scene,
                state: ref.watch(skyOverridesProvider).apply(_base),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Exact tile labels only: the STRAIN tile's 'RULE LOAD' unit string is
    // one Text widget, so an exact 'LOAD' match would only hit a real tile.
    expect(find.text('VOL'), findsNothing);
    expect(find.text('LOAD'), findsNothing);
    expect(find.text('1RM'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
