import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/sky_state_source.dart';
import 'package:illunis/features/dashboard/dashboard_page.dart';
import 'package:illunis/features/debug/sky_debug_sheet.dart';
import 'package:illunis/features/shell/dream_shell.dart';
import 'package:illunis/features/shell/shell_header.dart';
import 'package:illunis/main.dart';

const base = SkyState(
  timeOfDay: 0.5,
  dayOfYear: 252,
  epochDays: 9747.4,
  latitudeDeg: 52.23,
  moonPhase: 0.25,
);

void main() {
  testWidgets('mock preview and local history have distinct provenance', (
    tester,
  ) async {
    final day = dayKey(DateTime.now());
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWith((ref) => AppStore.memory()),
        journalFiguresProvider.overrideWithValue(
          TodayFigures(
            day: day,
            entryCount: 1,
            summary: DaySummary(day: day, intakeKcal: 550, strain: 0),
          ),
        ),
      ],
    );
    final scene = ValueNotifier<ResolvedScene?>(CelestialScene.resolve(base));
    addTearDown(scene.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: IllunisApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => DashboardPage(
                scene: scene,
                state: ref
                    .watch(skyOverridesProvider)
                    .apply(base.copyWith(strain: 0)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(S.sleep), findsOneWidget);
    expect(find.text(S.strain), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    container
        .read(skyOverridesProvider.notifier)
        .set(const SkyOverrides(preset: SkyPreset.restedMorning));
    await tester.pump();
    expect(find.text(S.mockData), findsOneWidget);
    expect(find.text(S.record), findsOneWidget);
    expect(find.text(S.local), findsOneWidget);
    expect(find.text('550'), findsOneWidget);
    container.read(journalDayProvider.notifier).prev();
    await tester.pump();
    expect(find.text(S.mockData), findsNothing);
    expect(find.text('0.00'), findsOneWidget);
    container.read(journalDayProvider.notifier).next();
    container
        .read(skyOverridesProvider.notifier)
        .set(const SkyOverrides(preset: SkyPreset.noData));
    await tester.pump();
    expect(find.text(S.noData), findsOneWidget);
    expect(find.text(S.emptyDash), findsNWidgets(2));
    expect(find.text('550'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets(
    '360px nightstand labels mock sleep and freezes drift with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: illunisOverrides(AppStore.memory()),
      );
      container
          .read(skyOverridesProvider.notifier)
          .set(const SkyOverrides(preset: SkyPreset.restedMorning));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IllunisApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 800),
                disableAnimations: true,
              ),
              child: DreamShell(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(S.mockData), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('NIGHTSTAND')),
        ).style.decoration,
        isNot(TextDecoration.underline),
      );
      final transform = find
          .descendant(
            of: find.byType(DreamShell),
            matching: find.byType(Transform),
          )
          .first;
      final before = tester.widget<Transform>(transform).transform.clone();
      await tester.pump(const Duration(seconds: 181));
      expect(tester.widget<Transform>(transform).transform, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets('weather debug controls scroll above phone navigation inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: illunisOverrides(AppStore.memory()),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: IllunisApp(
          home: Scaffold(body: SizedBox(key: key)),
        ),
      ),
    );
    showSkyDebugSheet(key.currentContext!);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    container
        .read(skyOverridesProvider.notifier)
        .set(const SkyOverrides(weatherPreset: WeatherPreset.snow));
    await tester.pump();
    expect(find.text('WEATHER · SIMULATED'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -650),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PREVIEW NIGHTSTAND').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('header wordmark derives ink from the resolved sky', (
    tester,
  ) async {
    final scene = ValueNotifier<ResolvedScene?>(CelestialScene.resolve(base));
    addTearDown(scene.dispose);
    await tester.pumpWidget(
      IllunisApp(
        home: Scaffold(body: ShellHeader(scene: scene)),
      ),
    );
    final noonInk = tester.widget<Text>(find.text('ILLUNIS')).style!.color;
    scene.value = CelestialScene.resolve(base.copyWith(timeOfDay: 0));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('ILLUNIS')).style!.color,
      isNot(noonInk),
    );
  });
}
