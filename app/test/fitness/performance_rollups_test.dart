import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/fitness/performance/performance_rollups.dart';
import 'package:illunis/core/journal/parser.dart';

void main() {
  group('computeRollingVolume honesty and baselines', () {
    test('returns null figures on days with no lifting', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      final baseline = computeRollingVolume(store, day);

      expect(baseline.day, day);
      expect(baseline.todayVolumeKg, isNull);
      expect(baseline.totalWindowVolumeKg, isNull);
      expect(baseline.dailyMeanVolumeKg, isNull);
      expect(baseline.trainingDaysCount, 0);
      expect(baseline.trainingDayMeanVolumeKg, isNull);
      expect(baseline.volumeRatioVsBaseline, isNull);
    });

    test('aggregates 28-day window volume and ratio vs baseline', () async {
      final store = AppStore.memory();
      const day = '2026-09-11';

      // Day 1 (today): bench 100x5x3 = 1500 kg
      final p1 = parseJournal(
        JournalEntry(id: 'j1', at: DateTime(2026, 9, 11, 10), text: 'bench 100x5x3'),
      );
      await store.addDerived(newSets: p1.sets);

      // 5 days ago: bench 80x5x3 = 1200 kg
      final p2 = parseJournal(
        JournalEntry(id: 'j2', at: DateTime(2026, 9, 6, 10), text: 'bench 80x5x3'),
      );
      await store.addDerived(newSets: p2.sets);

      final baseline = computeRollingVolume(store, day);

      expect(baseline.todayVolumeKg, 1500.0);
      expect(baseline.trainingDaysCount, 2);
      expect(baseline.totalWindowVolumeKg, 2700.0);
      // Training day mean = 2700 / 2 = 1350 kg
      expect(baseline.trainingDayMeanVolumeKg, 1350.0);
      // Ratio = 1500 / 1350 = 1.111...
      expect(baseline.volumeRatioVsBaseline, closeTo(1500 / 1350, 1e-6));
    });
  });

  group('computeRollingStrain and ACWR', () {
    test('strain figures are null when no activities or strain logged', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      final strainBaseline = computeRollingStrain(store, day);

      expect(strainBaseline.day, day);
      expect(strainBaseline.todayStrain, isNull);
      expect(strainBaseline.todayLoad, isNull);
      expect(strainBaseline.acute7DayMeanLoad, isNull);
      expect(strainBaseline.chronic28DayMeanLoad, isNull);
      expect(strainBaseline.acuteToChronicWorkloadRatio, isNull);
    });

    test('computes ACWR when load is present across acute/chronic window', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      // Add a session with duration and RPE
      store.activities.add(
        const ActivityEntry(
          id: 'a1',
          journalEntryId: 'j1',
          day: day,
          label: 'Run',
          kcal: 500.0,
          disciplineId: 'run',
          minutes: 60,
          rpe: 8,
          confirmed: true,
        ),
      );
      store.summaries.add(
        const DaySummary(
          day: day,
          strain: 14.5,
        ),
      );

      final baseline = computeRollingStrain(store, day);

      expect(baseline.todayStrain, 14.5);
      expect(baseline.todayLoad, isNotNull);
      expect(baseline.acute7DayMeanLoad, isNotNull);
      expect(baseline.chronic28DayMeanLoad, isNotNull);
      expect(baseline.acuteToChronicWorkloadRatio, isNotNull);
      // Acute (7-day average) should be 4x higher than 28-day chronic for a single isolated day:
      // 28 / 7 = 4.0
      expect(baseline.acuteToChronicWorkloadRatio, closeTo(4.0, 1e-4));
    });
  });

  group('computeExerciseOneRmBaselines', () {
    test('tracks today 1RM, previous best, all-time best, and delta', () async {
      final store = AppStore.memory();
      const dayToday = '2026-09-11';

      // Past lift: squat 100 kg 5 reps (Epley: 100 * (1 + 5/30) = 116.67 kg)
      final pOld = parseJournal(
        JournalEntry(id: 'j1', at: DateTime(2026, 8, 15, 10), text: 'squat 100 kg 5 reps'),
      );
      await store.addDerived(newSets: pOld.sets);

      // Today lift: squat 110 kg 5 reps (Epley: 110 * (1 + 5/30) = 128.33 kg)
      final pToday = parseJournal(
        JournalEntry(id: 'j2', at: DateTime(2026, 9, 11, 10), text: 'squat 110 kg 5 reps'),
      );
      await store.addDerived(newSets: pToday.sets);

      final baselines = computeExerciseOneRmBaselines(store, dayToday);
      expect(baselines, hasLength(1));

      final squat = baselines.first;
      expect(squat.exerciseId, 'barbell-squat');
      expect(squat.todayEpleyKg, closeTo(128.333, 1e-3));
      expect(squat.previousBestEpleyKg, closeTo(116.667, 1e-3));
      expect(squat.allTimeBestEpleyKg, closeTo(128.333, 1e-3));
      expect(squat.deltaEpleyKg, closeTo(128.333 - 116.667, 1e-3));
    });
  });

  group('computePerformanceRollup', () {
    test('bundles volume, strain, and 1rm baselines', () {
      final store = AppStore.memory();
      const day = '2026-09-11';

      final rollup = computePerformanceRollup(store, day);

      expect(rollup.day, day);
      expect(rollup.volume, isNotNull);
      expect(rollup.strain, isNotNull);
      expect(rollup.lifts, isEmpty);
    });
  });
}
