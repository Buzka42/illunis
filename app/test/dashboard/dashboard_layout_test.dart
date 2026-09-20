import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/sky_state_source.dart';
import 'package:illunis/features/dashboard/dashboard_page.dart';
import 'package:illunis/main.dart';

void main() {
  for (final scenario in [
    (name: 'populated', width: 360.0, height: 804.0, scale: 1.0, data: true),
    (name: 'empty', width: 360.0, height: 804.0, scale: 1.0, data: false),
    (name: 'large-text', width: 320.0, height: 640.0, scale: 2.0, data: true),
  ]) {
    testWidgets(
      'dashboard ${scenario.name}: ordered evidence and reachable instruments',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, scenario.height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          for (final font in [
            ('Inter', 'Inter-Regular.ttf'),
            ('JetBrains Mono', 'JetBrainsMono-Variable.ttf'),
          ]) {
            await (FontLoader(
              font.$1,
            )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
          }
        });
        final store = AppStore.memory();
        final now = DateTime.now();
        if (scenario.data) {
          for (var i = 0; i < 14; i++) {
            store.summaries.add(
              DaySummary(
                day: dayKey(DateTime(now.year, now.month, now.day - i)),
                intakeKcal: 2450,
                expenditureKcal: 2300,
                sleepHours: i == 3
                    ? null
                    : [7.5, 6.8, 8.1, 7.0, 6.5, 8.0, 7.2][i % 7],
                moveMinutes: i == 2
                    ? null
                    : i < 7
                    ? 45
                    : 30,
                steps: 8200,
                strain: 0.42,
              ),
            );
          }
        }
        final container = ProviderContainer(overrides: illunisOverrides(store));
        container
            .read(skyOverridesProvider.notifier)
            .set(const SkyOverrides(timeOfDay: 0.5));
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundary,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(scenario.width, scenario.height),
                  textScaler: TextScaler.linear(scenario.scale),
                ),
                child: const IllunisApp(),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(find.text('Energy')).dy,
          lessThan(tester.getTopLeft(find.text('Movement')).dy),
        );
        expect(
          tester.getTopLeft(find.text('Movement')).dy,
          lessThan(tester.getTopLeft(find.text('SLEEP')).dy),
        );
        if (scenario.data) {
          expect(find.textContaining('JNL KCAL EST'), findsOneWidget);
          expect(find.text('6/7 · JNL 6'), findsOneWidget);
          expect(find.textContaining('6/7 NIGHTS'), findsOneWidget);
        } else {
          expect(find.textContaining('0/7 NIGHTS'), findsOneWidget);
          expect(find.textContaining('— KCAL'), findsNWidgets(2));
        }
        await _capture(tester, boundary, scenario.name);
        final scroll = find.descendant(
          of: find.byType(DashboardPage),
          matching: find.byType(SingleChildScrollView),
        );
        await tester.drag(scroll, const Offset(0, -1500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('SUN'));
        expect(find.text('SUN').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('MOON'));
        expect(find.text('MOON').hitTestable(), findsOneWidget);
        await _capture(tester, boundary, '${scenario.name}-supporting');
        await tester.ensureVisible(find.text('WEATHER'));
        await tester.tap(find.text('WEATHER').hitTestable());
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        store.dispose();
      },
    );
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['ILLUNIS_ASTRA_CAPTURE'];
  if (directory == null) return;
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
  await tester.pump(const Duration(milliseconds: 50));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}
