import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/health/rollups.dart';
import 'package:illunis/core/journal/parser.dart';

void main() {
  JournalEntry entry(String text, {DateTime? at}) => JournalEntry(
        id: 'e1',
        at: at ?? DateTime(2026, 9, 6, 18, 0),
        text: text,
      );

  group('Step parsing - numeric formats', () {
    test('standard integers: 10000 steps and 8500 krokow', () {
      final p1 = parseJournal(entry('10000 steps'));
      expect(p1.steps, hasLength(1));
      expect(p1.steps.first.steps, 10000);

      final p2 = parseJournal(entry('8500 krokow'));
      expect(p2.steps, hasLength(1));
      expect(p2.steps.first.steps, 8500);

      final p3 = parseJournal(entry('8 500 kroków'));
      expect(p3.steps, hasLength(1));
      expect(p3.steps.first.steps, 8500);
    });

    test('k suffix: 10k, 10.5k, 12,5k', () {
      final p1 = parseJournal(entry('10k steps'));
      expect(p1.steps.single.steps, 10000);

      final p2 = parseJournal(entry('10.5k steps'));
      expect(p2.steps.single.steps, 10500);

      final p3 = parseJournal(entry('12,5k kroków'));
      expect(p3.steps.single.steps, 12500);
    });

    test('case insensitivity and inflection variations', () {
      final p1 = parseJournal(entry('Walked 7500 STEPS today'));
      expect(p1.steps.single.steps, 7500);

      final p2 = parseJournal(entry('Zrobilem 6200 kroki'));
      expect(p2.steps.single.steps, 6200);

      final p3 = parseJournal(entry('Przeszedłem 9100 kroków'));
      expect(p3.steps.single.steps, 9100);
    });
  });

  group('Step parsing - number words', () {
    test('English number words', () {
      final p1 = parseJournal(entry('ten thousand steps'));
      expect(p1.steps.single.steps, 10000);

      final p2 = parseJournal(entry('twelve thousand five hundred steps'));
      expect(p2.steps.single.steps, 12500);

      final p3 = parseJournal(entry('fifteen hundred steps'));
      expect(p3.steps.single.steps, 1500);

      final p4 = parseJournal(entry('two thousand steps'));
      expect(p4.steps.single.steps, 2000);
    });

    test('Polish number words', () {
      final p1 = parseJournal(entry('dziesiec tysiecy krokow'));
      expect(p1.steps.single.steps, 10000);

      final p2 = parseJournal(entry('dziesięć tysięcy kroków'));
      expect(p2.steps.single.steps, 10000);

      final p3 = parseJournal(entry('dwa tysiace krokow'));
      expect(p3.steps.single.steps, 2000);

      final p4 = parseJournal(entry('piętnaście tysięcy kroków'));
      expect(p4.steps.single.steps, 15000);

      final p5 = parseJournal(entry('trzy tysiace piecset krokow'));
      expect(p5.steps.single.steps, 3500);
    });
  });

  group('Step parsing - bounds discipline', () {
    test('rejects counts below 50', () {
      final p = parseJournal(entry('30 steps'));
      expect(p.steps, isEmpty);
    });

    test('rejects counts above 150000', () {
      final p = parseJournal(entry('200000 steps'));
      expect(p.steps, isEmpty);
    });

    test('accepts boundary counts', () {
      final minP = parseJournal(entry('50 steps'));
      expect(minP.steps.single.steps, 50);

      final maxP = parseJournal(entry('150000 steps'));
      expect(maxP.steps.single.steps, 150000);
    });
  });

  group('Step persistence and rollups', () {
    test('store addDerived and stepsOn aggregation', () async {
      final store = AppStore.memory();
      const day = '2026-09-06';
      final e1 = JournalEntry(id: 'j1', at: DateTime(2026, 9, 6, 10), text: '5000 steps');
      final p1 = parseJournal(e1);
      await store.addDerived(newSteps: p1.steps);

      expect(store.stepsOn(day), 5000);

      final e2 = JournalEntry(id: 'j2', at: DateTime(2026, 9, 6, 16), text: '3500 krokow');
      final p2 = parseJournal(e2);
      await store.addDerived(newSteps: p2.steps);

      expect(store.stepsOn(day), 8500);
    });

    test('revertJournalEntry removes steps from store', () async {
      final store = AppStore.memory();
      const day = '2026-09-06';
      final e = JournalEntry(id: 'j1', at: DateTime(2026, 9, 6, 10), text: '6000 steps');
      final p = parseJournal(e);
      await store.addDerived(newSteps: p.steps);

      expect(store.stepsOn(day), 6000);

      await store.revertJournalEntry('j1');
      expect(store.stepsOn(day), isNull);
      expect(store.steps, isEmpty);
    });

    test('rollups include daily steps in DaySummary', () async {
      final store = AppStore.memory();
      const day = '2026-09-06';
      final e = JournalEntry(id: 'j1', at: DateTime(2026, 9, 6, 12), text: '7200 steps');
      final p = parseJournal(e);
      await store.addDerived(newSteps: p.steps);

      await recomputeSummaries(store, days: {day});
      final summary = store.summaryOn(day);
      expect(summary?.steps, 7200);
    });

    test('JSON import/export preserves steps', () async {
      final store = AppStore.memory();
      const day = '2026-09-06';
      final e = JournalEntry(id: 'j1', at: DateTime(2026, 9, 6, 12), text: '8800 steps');
      final p = parseJournal(e);
      await store.addDerived(newSteps: p.steps);

      final json = store.exportJson();
      final restored = AppStore.memory();
      await restored.importJson(json);

      expect(restored.stepsOn(day), 8800);
      expect(restored.steps.single.steps, 8800);
    });
  });
}
