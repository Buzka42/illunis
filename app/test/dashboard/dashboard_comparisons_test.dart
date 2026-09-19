import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/wearables/life_stats.dart';
import 'package:illunis/core/wearables/wearable_data.dart';
import 'package:illunis/features/dashboard/dashboard_comparisons.dart';

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

  group('intake/burn pair', () {
    test('shared scale is the max of the two observed values', () {
      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {sel: stats(day: sel, intake: 2150, burn: 2600)},
      );
      expect(c.intakeBurn.sharedScaleMax, 2600);
      expect(c.intakeBurn.balanceKcal, -450);
      expect(
        c.intakeBurn.intakeShareOfBurn,
        closeTo(2150 / 2600, 1e-9),
      );
    });

    test('journal burn is flagged estimated; wearable burn is not', () {
      final journal = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {sel: stats(day: sel, burn: 2200)},
      );
      expect(journal.intakeBurn.burnEstimated, isTrue);

      final measured = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {
          sel: stats(day: sel, burn: 2500, burnSource: StatSource.wearable),
        },
      );
      expect(measured.intakeBurn.burnEstimated, isFalse);
    });

    test('pending estimates are excluded from figures but flagged', () {
      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {sel: stats(day: sel, intake: 1800, burn: 2400)},
        pendingIntakeCount: 2,
        pendingBurnCount: 1,
      );
      // Pending kcal never leaks into the observed figures.
      expect(c.intakeBurn.intake.value, 1800);
      expect(c.intakeBurn.burn.value, 2400);
      expect(c.intakeBurn.hasPending, isTrue);
      expect(c.intakeBurn.pendingIntakeCount, 2);
      expect(c.intakeBurn.pendingBurnCount, 1);
    });

    test('percentages against zero or absent burn are undefined', () {
      final zeroBurn = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {sel: stats(day: sel, intake: 1800, burn: 0)},
      );
      expect(zeroBurn.intakeBurn.intakeShareOfBurn, isNull);

      final absent = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {sel: stats(day: sel, intake: 1800)},
      );
      expect(absent.intakeBurn.intakeShareOfBurn, isNull);
      expect(absent.intakeBurn.balanceKcal, isNull);
      expect(absent.intakeBurn.sharedScaleMax, 1800);

      final bothAbsent = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {},
      );
      expect(bothAbsent.intakeBurn.sharedScaleMax, isNull);
      expect(bothAbsent.intakeBurn.burnEstimated, isNull);
    });
  });

  group('duplicate sources resolve once, never summed', () {
    test('resolveLifeStats journal-wins-ties feeds the builder singly', () {
      final store = AppStore.memory();
      store.summaries.add(
        const DaySummary(
          day: sel,
          intakeKcal: 2000,
          expenditureKcal: 2200,
          moveMinutes: 45,
          sleepHours: 7.5,
        ),
      );
      const wearable = WearableDailyData(
        caloriesBurned: 2500,
        activeMinutes: 60,
        sleepHours: 8.2,
      );
      final resolved =
          resolveLifeStats(store: store, day: sel, wearable: wearable);
      // One value per metric — the journal one — never a sum.
      expect(resolved.caloriesBurned.value, 2200);
      expect(resolved.activeMinutes.value, 45);
      expect(resolved.sleep.value, 7.5);

      final c = buildDashboardComparisons(
        selectedDay: sel,
        dayStats: {sel: resolved},
      );
      expect(c.intakeBurn.burn.value, 2200);
      expect(c.movement.current.observedCount, 1);
      expect(c.movement.current.meanActiveMinutes, 45);
    });
  });

  group('movement windows', () {
    test('incomplete weeks average observed days only, never zero-fill', () {
      final days = <String, DailyLifeStats>{
        for (var i = -6; i <= 0; i++)
          if (i.isEven) day(sel, i): stats(day: day(sel, i), active: 30),
      };
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      expect(c.movement.current.observedCount, 4);
      expect(c.movement.current.meanActiveMinutes, 30);
      expect(c.movement.current.coverage, closeTo(4 / 7, 1e-9));
    });

    test('no directional verdict when coverage is thin', () {
      final days = <String, DailyLifeStats>{
        day(sel, 0): stats(day: day(sel, 0), active: 60),
        day(sel, -7): stats(day: day(sel, -7), active: 10),
      };
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      expect(c.movement.current.observedCount, 1);
      expect(c.movement.current.isThin, isTrue);
      expect(c.movement.deltaMean, isNull);
      expect(c.movement.hasVerdict, isFalse);
    });

    test('full windows produce a delta verdict', () {
      final days = <String, DailyLifeStats>{
        for (var i = -13; i <= 0; i++)
          day(sel, i): stats(
            day: day(sel, i),
            active: i >= -6 ? 40.0 : 20.0,
          ),
      };
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      expect(c.movement.current.observedCount, 7);
      expect(c.movement.previous.observedCount, 7);
      expect(c.movement.deltaMean, 20);
      expect(c.movement.hasVerdict, isTrue);
    });

    test('mixed-source windows expose composition, not a single label', () {
      final days = <String, DailyLifeStats>{
        for (var i = -6; i <= 0; i++)
          day(sel, i): stats(
            day: day(sel, i),
            active: 30,
            activeSource:
                i.isEven ? StatSource.journal : StatSource.wearable,
          ),
      };
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      expect(
        c.movement.current.sourceCounts,
        {StatSource.journal: 4, StatSource.wearable: 3},
      );
      expect(c.movement.current.unanimousSource, isNull);
    });

    test('midnight rollover: windows cross month boundaries', () {
      const first = '2026-09-01';
      final days = <String, DailyLifeStats>{
        for (var i = -13; i <= 0; i++)
          day(first, i): stats(day: day(first, i), active: 25),
      };
      final c = buildDashboardComparisons(selectedDay: first, dayStats: days);
      expect(c.movement.current.startDay, '2026-08-26');
      expect(c.movement.current.endDay, '2026-09-01');
      expect(c.movement.previous.startDay, '2026-08-19');
      expect(c.movement.previous.endDay, '2026-08-25');
      expect(c.movement.current.observedCount, 7);
      expect(c.movement.deltaMean, 0);
    });

    test('selected-day changes shift the windows', () {
      final days = <String, DailyLifeStats>{
        for (var i = -20; i <= 0; i++)
          day(sel, i): stats(day: day(sel, i), active: (i + 20).toDouble()),
      };
      final a = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      final earlier = day(sel, -3);
      final b = buildDashboardComparisons(selectedDay: earlier, dayStats: days);
      expect(b.movement.current.endDay, earlier);
      expect(
        a.movement.current.meanActiveMinutes,
        isNot(b.movement.current.meanActiveMinutes),
      );
    });
  });

  group('sleep series', () {
    test('seven nights, observed range, hours only', () {
      final days = <String, DailyLifeStats>{
        for (var i = -6; i <= 0; i++)
          day(sel, i): stats(day: day(sel, i), sleep: 6.0 + (i + 6) * 0.5),
      };
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      expect(c.sleep.nights.length, 7);
      expect(c.sleep.observedCount, 7);
      expect(c.sleep.minHours, 6.0);
      expect(c.sleep.maxHours, 9.0);
      expect(c.sleep.meanHours, closeTo(7.5, 1e-9));
    });

    test('absent nights stay absent; range covers observed only', () {
      final days = <String, DailyLifeStats>{
        day(sel, 0): stats(day: day(sel, 0), sleep: 7.0),
        day(sel, -6): stats(day: day(sel, -6), sleep: 8.0),
      };
      final c = buildDashboardComparisons(selectedDay: sel, dayStats: days);
      expect(c.sleep.observedCount, 2);
      expect(c.sleep.minHours, 7.0);
      expect(c.sleep.maxHours, 8.0);
      expect(c.sleep.meanHours, 7.5);
      expect(c.sleep.nights[3].hours, isNull);
    });
  });
}
