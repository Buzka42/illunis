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
import 'package:illunis/features/dashboard/dashboard_page.dart';
import 'package:illunis/features/journal/journal_page.dart';
import 'package:illunis/main.dart';

void main() {
  testWidgets(
    'Blade surfaces paginate records and retain Settings without bottom bar',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2412);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(bottom: 144, top: 72);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
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
      final day = dayKey(now);
      store.summaries.add(
        DaySummary(
          day: day,
          intakeKcal: 2450,
          expenditureKcal: 2300,
          sleepHours: 7.5,
          moveMinutes: 45,
          steps: 8200,
          strain: 0.42,
          digest: 'Intake 2450 kcal. Movement 45 min.',
          digestSource: 'local',
        ),
      );
      for (var i = 0; i < 20; i++) {
        store.journal.add(
          JournalEntry(
            id: '$i',
            at: DateTime(now.year, now.month, now.day, 8, i),
            text:
                'Entry $i: a long reviewed journal line that remains available in full when editing.',
          ),
        );
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: illunisOverrides(store),
          child: RepaintBoundary(key: boundary, child: const IllunisApp()),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(DashboardPage),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(find.text('2450'), findsOneWidget);
      expect(find.text('REST HR'), findsOneWidget);
      expect(find.text('INSIGHTS'), findsNothing);
      expect(find.text('ILLUNIS 1.0'), findsNothing);
      await _capture(tester, boundary, 'dashboard');
      await tester.drag(find.byType(PageView), const Offset(600, 0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('JOURNAL'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JournalPage),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(find.text('OLDER'), findsOneWidget);
      final first = find.textContaining('Entry 19:');
      expect(first, findsOneWidget);
      await tester.tap(find.text('OLDER'));
      await tester.pump();
      expect(first, findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, 'journal');
      await tester.longPress(find.text('JOURNAL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SETTINGS'), findsOneWidget);
      await tester.tap(find.text('QUICK GUIDE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Swipe left for Dashboard'), findsOneWidget);
      expect(find.textContaining('Debug builds:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('SKIP'));
      await tester.tap(find.text('SKIP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final burn = find.textContaining('BURN SOURCE');
      await tester.ensureVisible(burn);
      await tester.tap(burn);
      await tester.pump();
      expect(store.profile.caloriesBurnedSource, 'wearable');
      expect(
        Profile.fromJson(store.profile.toJson()).caloriesBurnedSource,
        'wearable',
      );
      Navigator.of(tester.element(burn)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 30; i++) {
        store.nutrition.add(
          NutritionEntry(
            id: 'pending-$i',
            journalEntryId: '0',
            day: day,
            label: 'Pending $i',
            kcal: 200,
          ),
        );
      }
      await store.putProfile(store.profile);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(JournalPage),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(JournalPending)).height,
        lessThanOrEqualTo(148),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  const directory = String.fromEnvironment('ILLUNIS_V2_CAPTURE');
  if (directory.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 3)))!;
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name-widget.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}
