import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/fitness/progress.dart';
import 'package:illunis/core/journal/marks.dart';
import 'package:illunis/core/journal/repository.dart';
import 'package:illunis/core/strength/progress.dart';

void main() {
  test('revert removes the page and everything it produced', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    final e = await repo.log('bench 80x5x3\nate oatmeal');
    expect(store.journal, hasLength(1));
    expect(store.sets, isNotEmpty);
    expect(store.nutrition, isNotEmpty);
    await repo.revert(e.id);
    expect(store.journal, isEmpty);
    expect(store.sets, isEmpty);
    expect(store.nutrition, isEmpty);
  });

  test(
    'unconfirmed food is excluded from the day total until confirmed',
    () async {
      final store = AppStore.memory();
      final repo = JournalRepository(store);
      await repo.log('ate oatmeal');
      final day = dayKey(DateTime.now());
      expect(store.summaryOn(day)?.intakeKcal, isNull);
      await repo.confirmFood(store.nutrition.single.id);
      expect(store.summaryOn(day)?.intakeKcal, closeTo(320, 1e-9));
    },
  );

  test('a trivial drink is intake without a confirm', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('drank coffee');
    final day = dayKey(DateTime.now());
    expect(store.nutrition.single.confirmed, isTrue);
    expect(store.summaryOn(day)?.intakeKcal, closeTo(5, 1e-9));
  });

  test('two bananas scale the estimate into the day total', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('ate 2 bananas');
    await repo.confirmFood(store.nutrition.single.id);
    final day = dayKey(DateTime.now());
    expect(store.summaryOn(day)?.intakeKcal, closeTo(210, 1e-9));
  });

  test('1RM progress reports a delta against the prior best', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('bench 80x5', at: DateTime(2026, 8, 1, 18));
    await repo.log('bench 85x5', at: DateTime(2026, 8, 8, 18));
    final bests = bestLiftsOn(store, '2026-08-08');
    expect(bests, hasLength(1));
    expect(bests.first.epleyKg, closeTo(85 * (1 + 5 / 30), 1e-9));
    expect(bests.first.previousKg, closeTo(80 * (1 + 5 / 30), 1e-9));
    expect(bests.first.deltaKg, greaterThan(0));
  });

  test('confirm all promotes food and activity estimates', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('ate oatmeal\nran 40 min');
    final day = dayKey(DateTime.now());
    expect(store.nutrition.single.confirmed, isFalse);
    expect(store.activities.single.confirmed, isFalse);
    await repo.confirmAll(day);
    expect(store.nutrition.single.confirmed, isTrue);
    expect(store.activities.single.confirmed, isTrue);
    expect(store.summaryOn(day)?.intakeKcal, closeTo(320, 1e-9));
  });

  test('a rest day with a log is zero strain, not unknown', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('rest day');
    final day = dayKey(DateTime.now());
    expect(store.summaryOn(day)?.strain, 0);
    expect(store.summaryOn(day)?.digest, 'Rest.');
    expect(store.summaryOn(day)?.digestSource, 'local');
  });

  test(
    'an unconfirmed run is not strain or a session until confirmed',
    () async {
      final store = AppStore.memory();
      final repo = JournalRepository(store);
      await repo.log('ran 5k');
      final day = dayKey(DateTime.now());
      expect(store.summaryOn(day)?.strain, isNull);
      expect(store.summaryOn(day)?.distanceKm, isNull);
      expect(store.summaryOn(day)?.digest, isNull);
      expect(sessionsOn(store, day), isEmpty);
      await repo.confirmActivity(store.activities.single.id);
      expect(store.summaryOn(day)?.strain, isNotNull);
      expect(store.summaryOn(day)?.distanceKm, 5);
      expect(sessionsOn(store, day), isNotEmpty);
      expect(store.summaryOn(day)?.digest, contains('RUN'));
    },
  );

  test('confirming a meal refreshes the local digest', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('ate oatmeal');
    final day = dayKey(DateTime.now());
    expect(store.summaryOn(day)?.digest, 'Rest.');
    await repo.confirmFood(store.nutrition.single.id);
    expect(store.summaryOn(day)?.digest, contains('Intake 320 kcal'));
  });

  test('an AI digest survives a later rollup', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('rest day');
    final day = dayKey(DateTime.now());
    await store.putSummary(
      store
          .summaryOn(day)!
          .copyWith(digest: 'A quiet day.', digestSource: 'ai'),
    );
    await repo.log('ate oatmeal');
    expect(store.summaryOn(day)?.digest, 'A quiet day.');
    expect(store.summaryOn(day)?.digestSource, 'ai');
  });

  test('weight on a day is the last mass on or before it', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('weighed 80', at: DateTime(2026, 8, 1, 8));
    await repo.log('weighed 82', at: DateTime(2026, 8, 10, 8));
    expect(store.weightOnOrBefore('2026-08-05'), 80);
    expect(store.weightOnOrBefore('2026-08-10'), 82);
  });

  test('import restores a JSON export', () async {
    final a = AppStore.memory();
    final repo = JournalRepository(a);
    await repo.log('bench 80x5');
    final json = a.exportJson();
    final b = AppStore.memory();
    await b.importJson(json);
    expect(b.sets, hasLength(1));
    expect(b.journal.single.text, 'bench 80x5');
    expect(b.summaries.single.digestSource, a.summaries.single.digestSource);
  });

  test('a leading clock stamps the page and is not kept as prose', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('7:30 ran 5k', at: DateTime(2026, 9, 6, 22, 10));
    expect(store.journal.single.text, 'ran 5k');
    expect(store.journal.single.at.hour, 7);
    expect(store.journal.single.at.minute, 30);
    expect(
      timelineMarksOn(store, '2026-09-06').single,
      closeTo((7 + 30 / 60) / 24, 1e-9),
    );

    await repo.log('at 8am ate oatmeal', at: DateTime(2026, 9, 6, 22, 10));
    expect(store.journal.first.text, 'ate oatmeal');
    expect(store.journal.first.at.hour, 8);
    expect(store.journal.first.at.minute, 0);
  });

  test('this morning without a clock still stamps eight', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('this morning ran 5k', at: DateTime(2026, 9, 7, 22, 10));
    expect(store.journal.single.text, 'ran 5k');
    expect(store.journal.single.at, DateTime(2026, 9, 7, 8, 0));
    await repo.log('for lunch ate oatmeal', at: DateTime(2026, 9, 7, 22, 10));
    expect(store.journal.first.text, 'ate oatmeal');
    expect(store.journal.first.at.hour, 13);
    expect(store.nutrition.single.label, 'Oatmeal');
  });

  test('yesterday lands on the previous civil day', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('yesterday ran 5k', at: DateTime(2026, 9, 7, 8, 15));
    expect(store.journal.single.text, 'ran 5k');
    expect(store.journal.single.day, '2026-09-06');
    expect(store.activities.single.day, '2026-09-06');
  });

  test('slept poorly attaches to last night without inventing hours', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('slept 7h', at: DateTime(2026, 9, 7, 8));
    expect(store.sleeps.single.quality, isNull);
    await repo.log('slept poorly', at: DateTime(2026, 9, 7, 8, 5));
    expect(store.sleeps, hasLength(1));
    expect(store.sleeps.single.quality, closeTo(0.32, 1e-9));
    expect(store.sleeps.single.durationHours, closeTo(7, 1e-9));
    expect(store.summaryOn('2026-09-07')?.digest, contains('poorly'));
  });

  test('woke finishes last night without inventing a bedtime', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('went to bed at 23:10', at: DateTime(2026, 9, 6, 23, 15));
    expect(store.sleeps.single.isComplete, isFalse);
    expect(store.summaryOn('2026-09-06')?.sleepHours, isNull);
    await repo.log('woke at 6:45', at: DateTime(2026, 9, 7, 6, 50));
    expect(store.sleeps, hasLength(1));
    expect(store.sleeps.single.isComplete, isTrue);
    expect(store.sleeps.single.day, '2026-09-07');
    expect(store.sleeps.single.durationHours, closeTo(7 + 35 / 60, 1e-6));
    expect(
      store.summaryOn('2026-09-07')?.sleepHours,
      closeTo(7 + 35 / 60, 1e-6),
    );
    expect(store.summaryOn('2026-09-06')?.sleepHours, isNull);
  });

  test('timeline marks sit at the log time on that civil day', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('ran 5k', at: DateTime(2026, 9, 6, 18, 30));
    await repo.log('ate oatmeal', at: DateTime(2026, 9, 6, 12, 0));
    await repo.log('bench 80x5', at: DateTime(2026, 9, 5, 18, 0));
    final marks = timelineMarksOn(store, '2026-09-06');
    expect(marks, hasLength(2));
    expect(marks.first, closeTo(0.5, 1e-9));
    expect(marks.last, closeTo(18.5 / 24, 1e-9));
  });

  test('keep local can be cleared on an existing page', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    final e = await repo.log('ate oatmeal', excludedFromAi: true);
    expect(store.journal.single.excludedFromAi, isTrue);
    await repo.setKeepLocal(e.id, false);
    expect(store.journal.single.excludedFromAi, isFalse);
  });

  test('drop removes an estimate and leaves the page', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('ran 5k');
    expect(store.activities, hasLength(1));
    expect(store.activities.single.confirmed, isFalse);
    await repo.dropActivity(store.activities.single.id);
    expect(store.activities, isEmpty);
    expect(store.journal, hasLength(1));
  });

  test(
    'slept poorly lowers the night\'s score against the same hours',
    () async {
      final store = AppStore.memory();
      final repo = JournalRepository(store);
      await repo.log('slept 7h well', at: DateTime(2026, 9, 2, 8));
      await repo.log('slept 7h poorly', at: DateTime(2026, 9, 3, 8));
      final well = store.summaryOn('2026-09-02')!.sleepScore!;
      final poor = store.summaryOn('2026-09-03')!.sleepScore!;
      expect(poor, lessThan(well));
    },
  );

  test(
    'one confirmed meal and a run is today\'s energy, not a 7-day balance',
    () async {
      final store = AppStore.memory();
      final repo = JournalRepository(store);
      await repo.log('ate oatmeal');
      await repo.confirmFood(store.nutrition.single.id);
      await repo.log('ran 5k');
      await repo.confirmActivity(store.activities.single.id);
      final day = dayKey(DateTime.now());
      final s = store.summaryOn(day)!;
      expect(s.energyBalance, isNull);
      expect(s.energyKcal, isNotNull);
      expect(s.intakeKcal, closeTo(320, 1e-9));
      expect(s.energyKcal, closeTo(320 - s.expenditureKcal!, 1e-6));
    },
  );

  test('csv marks food and activity confirmation', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('ate oatmeal');
    await repo.log('ran 5k');
    final csv = store.exportCsv();
    expect(csv, startsWith('day,kind,label,value,confirmed'));
    expect(
      csv
          .split('\n')
          .any((l) => l.contains(',food,Oatmeal,') && l.endsWith(',0')),
      isTrue,
    );
    expect(
      csv.split('\n').any((l) => l.contains(',activity,') && l.endsWith(',0')),
      isTrue,
    );
    await repo.confirmFood(store.nutrition.single.id);
    await repo.confirmActivity(store.activities.single.id);
    final done = store.exportCsv();
    expect(
      done
          .split('\n')
          .any((l) => l.contains(',food,Oatmeal,') && l.endsWith(',1')),
      isTrue,
    );
    expect(
      done.split('\n').any((l) => l.contains(',activity,') && l.endsWith(',1')),
      isTrue,
    );
  });
}
