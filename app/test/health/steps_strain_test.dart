import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/health/rollups.dart';
import 'package:illunis/core/journal/parser.dart';

StepEntry stepEntry(
  String id,
  String day,
  int count, {
  String source = 'parsed',
}) => StepEntry(
  id: id,
  journalEntryId: 'j-$id',
  day: day,
  steps: count,
  source: source,
);

Future<AppStore> storeWithSteps(
  String day,
  List<StepEntry> entries,
) async {
  final store = AppStore.memory();
  await store.addDerived(newSteps: entries);
  await recomputeSummaries(store, days: {day});
  return store;
}

void main() {
  group('Steps dedup — one authoritative figure per day', () {
    test('journal + wearable collapse to the journal figure', () async {
      const day = '2026-09-06';
      final store = await storeWithSteps(day, [
        stepEntry('s1', day, 8000),
        stepEntry('w1', day, 8200, source: 'wearable'),
      ]);
      expect(store.stepsOn(day), 8000);
      expect(store.stepsSourceOn(day), 'journal');
      expect(store.summaryOn(day)?.steps, 8000);
      expect(store.summaryOn(day)?.stepsSource, 'journal');
    });

    test('wearable-only day collapses snapshots to max, not sum', () async {
      const day = '2026-09-06';
      final store = await storeWithSteps(day, [
        stepEntry('w1', day, 6000, source: 'wearable'),
        stepEntry('w2', day, 7500, source: 'wearable'),
      ]);
      expect(store.stepsOn(day), 7500);
      expect(store.stepsSourceOn(day), 'wearable');
      expect(store.summaryOn(day)?.steps, 7500);
      expect(store.summaryOn(day)?.stepsSource, 'wearable');
    });

    test('same-day journal logs still sum', () async {
      const day = '2026-09-06';
      final e1 = JournalEntry(
        id: 'j1',
        at: DateTime(2026, 9, 6, 10),
        text: '5000 steps',
      );
      final e2 = JournalEntry(
        id: 'j2',
        at: DateTime(2026, 9, 6, 16),
        text: '3500 krokow',
      );
      final store = AppStore.memory();
      await store.addDerived(newSteps: parseJournal(e1).steps);
      await store.addDerived(newSteps: parseJournal(e2).steps);
      expect(store.stepsOn(day), 8500);
    });
  });

  group('Strain from all activity', () {
    test('10k steps load equals a 400 kcal session (light training day)', () {
      // Justification: ~10k steps cost 300–500 kcal for an average adult,
      // so steps/10000 sits on the same scale as the existing
      // activityKcal/400 term. A 10k-step day reads as a light training day;
      // gym volume (volume/1000) still dominates big lifting days.
      expect(10000 / stepsPerLoadUnit, closeTo(1.0, 1e-9));
      expect(400 / 400.0, closeTo(10000 / stepsPerLoadUnit, 1e-9));
    });

    test('10k-step day with no gym yields strain in (0, 1]', () async {
      const day = '2026-09-06';
      final store = await storeWithSteps(day, [stepEntry('s1', day, 10000)]);
      expect(dailyLoad(store, day), closeTo(1.0, 1e-9));
      final strain = store.summaryOn(day)?.strain;
      expect(strain, isNotNull);
      expect(strain!, greaterThan(0));
      expect(strain, lessThanOrEqualTo(1.0));
    });

    test('heavy day clamps strain at 1', () async {
      const day = '2026-09-06';
      final store = await storeWithSteps(day, [stepEntry('s1', day, 60000)]);
      final strain = store.summaryOn(day)?.strain;
      expect(strain, isNotNull);
      expect(strain!, lessThanOrEqualTo(1.0));
    });

    test('pure rest day with a log stays strain 0', () async {
      const day = '2026-09-06';
      final store = AppStore.memory();
      await store.addJournal(
        JournalEntry(
          id: 'j1',
          at: DateTime(2026, 9, 6, 20),
          text: 'quiet rest day',
        ),
      );
      await recomputeSummaries(store, days: {day});
      expect(store.summaryOn(day)?.strain, 0.0);
      expect(store.summaryOn(day)?.steps, isNull);
    });

    test('blank day stays unknown, not rest', () async {
      const day = '2026-09-06';
      final store = AppStore.memory();
      await recomputeSummaries(store, days: {day});
      final s = store.summaryOn(day);
      expect(s?.strain, isNull);
      expect(s?.steps, isNull);
      expect(s?.stepsSource, isNull);
      expect(s?.recovery, isNull);
    });

    test('recovery stays sleep-derived on a big-step day', () async {
      const day = '2026-09-06';
      final store = await storeWithSteps(day, [stepEntry('s1', day, 20000)]);
      // Movement feeds strain, never recovery: no sleep logged, no recovery.
      expect(store.summaryOn(day)?.strain, greaterThan(0));
      expect(store.summaryOn(day)?.recovery, isNull);
    });
  });
}
