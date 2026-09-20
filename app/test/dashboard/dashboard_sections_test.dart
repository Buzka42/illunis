import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/sky_state_source.dart';
import 'package:illunis/core/wearables/life_stats.dart';
import 'package:illunis/features/dashboard/dashboard_comparisons.dart';
import 'package:illunis/main.dart';

DailyLifeStats stats({
  required String day,
  double? intake,
  double? burn,
  StatSource burnSource = StatSource.journal,
  double? active,
  StatSource activeSource = StatSource.journal,
  double? sleep,
  StatSource sleepSource = StatSource.journal,
}) {
  absent<T>(StatSource s) => LifeStat<T>.absent(s);
  return DailyLifeStats(
    day: day,
    caloriesBurned: burn == null
        ? absent<double>(StatSource.journal)
        : LifeStat<double>(value: burn, source: burnSource),
    calorieIntake: intake == null
        ? absent<double>(StatSource.journal)
        : LifeStat<double>(value: intake, source: StatSource.journal),
    steps: absent<int>(StatSource.journal),
    sleep: sleep == null
        ? absent<double>(StatSource.journal)
        : LifeStat<double>(value: sleep, source: sleepSource),
    restingHr: absent<int>(StatSource.wearable),
    activeMinutes: active == null
        ? absent<double>(StatSource.journal)
        : LifeStat<double>(value: active, source: activeSource),
    restedness: absent<double>(StatSource.rule),
  );
}

String day(String base, int delta) {
  final d = dayKeyDate(base);
  return dayKey(DateTime(d.year, d.month, d.day + delta));
}

void main() {
  const sel = '2026-09-19';

  group('dashboard section fixtures (model)', () {
    test('missing: empty window renders absence, never zero', () {
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: {});
      expect(c.intakeBurn.intake.value, isNull);
      expect(c.intakeBurn.burn.value, isNull);
      expect(c.intakeBurn.sharedScaleMax, isNull);
      expect(c.movement.current.meanActiveMinutes, isNull);
      expect(c.movement.current.observedCount, 0);
      expect(c.movement.hasVerdict, isFalse);
      expect(c.sleep.observedCount, 0);
      expect(c.sleep.meanHours, isNull);
    });

    test('sparse: means divide by observed count, never by 7', () {
      final dayStats = {
        day(sel, 0): stats(day: day(sel, 0), active: 60, sleep: 7.0),
        day(sel, -3): stats(day: day(sel, -3), active: 30, sleep: 8.0),
      };
      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: dayStats,
      );
      expect(c.movement.current.observedCount, 2);
      expect(c.movement.current.meanActiveMinutes, closeTo(45.0, 1e-9));
      expect(c.sleep.observedCount, 2);
      expect(c.sleep.meanHours, closeTo(7.5, 1e-9));
      // Thin coverage: no directional verdict.
      expect(c.movement.hasVerdict, isFalse);
    });

    test('mixed-source: composition exposed, no single label', () {
      final dayStats = {
        for (var i = -6; i <= 0; i++)
          day(sel, i): stats(
            day: day(sel, i),
            active: 40,
            activeSource: i.isEven
                ? StatSource.journal
                : StatSource.wearable,
            sleep: 7.0,
            sleepSource: StatSource.wearable,
          ),
      };
      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: dayStats,
      );
      expect(c.movement.current.observedCount, 7);
      expect(c.movement.current.sourceCounts[StatSource.journal], 4);
      expect(c.movement.current.sourceCounts[StatSource.wearable], 3);
      expect(c.movement.current.unanimousSource, isNull);
    });

    test('long values: shared scales take the max, balances stay signed', () {
      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {
          sel: stats(day: sel, intake: 12500, burn: 480),
        },
      );
      expect(c.intakeBurn.sharedScaleMax, 12500);
      expect(c.intakeBurn.balanceKcal, 12500 - 480);
      expect(
        c.intakeBurn.intakeShareOfBurn,
        closeTo(12500 / 480, 1e-9),
      );
    });

    test('headline and comparison share aggregation: today movement feeds the 7d mean', () {
      // Today's resolved active minutes must be one of the observed days in
      // the current window mean — never a separately computed figure.
      final dayStats = {
        for (var i = -6; i <= 0; i++)
          day(sel, i): stats(day: day(sel, i), active: 20 + i * 5.0),
      };
      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: dayStats,
      );
      final today = dayStats[sel]!.activeMinutes.value!;
      final observed = [
        for (var i = -6; i <= 0; i++) dayStats[day(sel, i)]!.activeMinutes.value!,
      ];
      expect(observed, contains(today));
      final mean = observed.reduce((a, b) => a + b) / observed.length;
      expect(c.movement.current.meanActiveMinutes, closeTo(mean, 1e-9));
      expect(c.movement.current.observedCount, 7);
    });
  });

  group('dashboard section measurability + fold', () {
    testWidgets('energy/movement/sleep/supporting carry keys; '
        'header..sleep fits 210dp at default scale', (tester) async {
      tester.view.physicalSize = const Size(360, 804);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore.memory();
      final now = DateTime.now();
      for (var i = 0; i < 14; i++) {
        store.summaries.add(
          DaySummary(
            day: dayKey(DateTime(now.year, now.month, now.day - i)),
            intakeKcal: 2450,
            expenditureKcal: 2300,
            sleepHours: [7.5, 6.8, 8.1, 7.0, 6.5, 8.0, 7.2][i % 7],
            moveMinutes: i < 7 ? 45 : 30,
            steps: 8200,
            strain: 0.42,
          ),
        );
      }
      final container = ProviderContainer(overrides: illunisOverrides(store));
      container
          .read(skyOverridesProvider.notifier)
          .set(const SkyOverrides(timeOfDay: 0.5));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 804),
              textScaler: TextScaler.linear(1.0),
            ),
            child: IllunisApp(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      for (final key in [
        'dashboard-energy',
        'dashboard-movement',
        'dashboard-sleep',
        'dashboard-supporting',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }

      final headerTop = tester.getTopLeft(find.text('DASHBOARD')).dy;
      final energyTop = tester.getTopLeft(find.text('Energy')).dy;
      expect(energyTop, greaterThan(headerTop));
      // Bottom of the complete 7-night sleep strip.
      final sleepBottom = tester
          .getBottomRight(find.byKey(const ValueKey('dashboard-sleep-marks')))
          .dy;
      expect(sleepBottom, greaterThan(energyTop));
      expect(
        sleepBottom - headerTop,
        lessThanOrEqualTo(210),
        reason: 'header + Energy..Movement..Sleep must fit 210dp',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      store.dispose();
    });
  });
}
