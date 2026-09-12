import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/wearables/health_bridge.dart';
import 'package:illunis/core/wearables/life_stats.dart';
import 'package:illunis/core/wearables/wearable_data.dart';

void main() {
  group('HealthBridge platform fallback', () {
    test('HealthBridge.create instantiates cleanly on test platform', () {
      final bridge = HealthBridge.create();
      expect(bridge, isNotNull);
      // In host test environment (Windows/desktop VM), it safely runs without throwing
      expect(bridge.isSupported, isFalse);
    });

    test('HealthBridge fallback returns null daily data', () async {
      final bridge = HealthBridge.create();
      final data = await bridge.getDailyData(DateTime(2026, 9, 11));
      expect(data, isNull);
    });
  });

  group('resolveLifeStats honesty and tie-breaking', () {
    test('empty store produces all absent stats with null values', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      final stats = resolveLifeStats(store: store, day: day);

      expect(stats.day, day);
      expect(stats.caloriesBurned.value, isNull);
      expect(stats.calorieIntake.value, isNull);
      expect(stats.steps.value, isNull);
      expect(stats.sleep.value, isNull);
      expect(stats.restingHr.value, isNull);
      expect(stats.activeMinutes.value, isNull);
      expect(stats.restedness.value, isNull);

      expect(stats.caloriesBurned.isPresent, isFalse);
      expect(stats.steps.isPresent, isFalse);
    });

    test('resting HR is wearable only and never estimated', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      // Even if journal has complete log with runs and sleep:
      store.summaries.add(
        const DaySummary(
          day: day,
          sleepHours: 8.0,
          moveMinutes: 60.0,
          expenditureKcal: 2400.0,
        ),
      );

      final statsWithoutWearable = resolveLifeStats(store: store, day: day);
      expect(statsWithoutWearable.restingHr.value, isNull);
      expect(statsWithoutWearable.restingHr.source, StatSource.wearable);

      final statsWithWearable = resolveLifeStats(
        store: store,
        day: day,
        wearable: const WearableDailyData(restingHr: 54),
      );
      expect(statsWithWearable.restingHr.value, 54);
      expect(statsWithWearable.restingHr.source, StatSource.wearable);
    });

    test('calorie intake is journal only', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      final statsWearableOnly = resolveLifeStats(
        store: store,
        day: day,
        wearable: const WearableDailyData(caloriesBurned: 2600.0),
      );
      expect(statsWearableOnly.calorieIntake.value, isNull);

      store.summaries.add(const DaySummary(day: day, intakeKcal: 2150.0));

      final statsJournal = resolveLifeStats(store: store, day: day);
      expect(statsJournal.calorieIntake.value, 2150.0);
      expect(statsJournal.calorieIntake.source, StatSource.journal);
    });

    test('journal wins ties when both journal and wearable data exist', () {
      final store = AppStore.memory();
      const day = '2026-09-11';
      store.summaries.add(
        const DaySummary(
          day: day,
          steps: 8000,
          sleepHours: 7.5,
          moveMinutes: 45.0,
          expenditureKcal: 2200.0,
        ),
      );

      const wearable = WearableDailyData(
        steps: 9500,
        sleepHours: 8.2,
        activeMinutes: 60.0,
        caloriesBurned: 2500.0,
      );

      final stats = resolveLifeStats(
        store: store,
        day: day,
        wearable: wearable,
      );

      expect(stats.steps.value, 8000);
      expect(stats.steps.source, StatSource.journal);

      expect(stats.sleep.value, 7.5);
      expect(stats.sleep.source, StatSource.journal);

      expect(stats.activeMinutes.value, 45.0);
      expect(stats.activeMinutes.source, StatSource.journal);

      expect(stats.caloriesBurned.value, 2200.0);
      expect(stats.caloriesBurned.source, StatSource.journal);
    });

    test(
      'step preference applies but reviewed journal sleep remains canonical',
      () {
        final store = AppStore.memory();
        const day = '2026-09-11';
        store.profile = store.profile.copyWith(
          stepsSource: 'wearable',
          sleepSource: 'wearable',
        );
        store.summaries.add(
          const DaySummary(day: day, steps: 8000, sleepHours: 7.0),
        );

        const wearable = WearableDailyData(steps: 11000, sleepHours: 7.8);

        final stats = resolveLifeStats(
          store: store,
          day: day,
          wearable: wearable,
        );

        expect(stats.steps.value, 11000);
        expect(stats.steps.source, StatSource.wearable);

        expect(stats.sleep.value, 7.0);
        expect(stats.sleep.source, StatSource.journal);
      },
    );

    test('restedness provenance: AI vs rule vs absent', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      // 1. Fully absent:
      final statsAbsent = resolveLifeStats(store: store, day: day);
      expect(statsAbsent.restedness.value, isNull);

      // 2. Rule evaluation from summary recovery:
      store.summaries.add(const DaySummary(day: day, recovery: 0.82));
      final statsRule = resolveLifeStats(store: store, day: day);
      expect(statsRule.restedness.value, 0.82);
      expect(statsRule.restedness.source, StatSource.rule);

      // 3. AI restedness overrides and labels StatSource.ai:
      final statsAi = resolveLifeStats(
        store: store,
        day: day,
        aiRestedness: 0.89,
      );
      expect(statsAi.restedness.value, 0.89);
      expect(statsAi.restedness.source, StatSource.ai);
    });
  });
}
