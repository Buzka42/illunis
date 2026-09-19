import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/journal/path_events.dart';
import 'package:illunis/core/wearables/wearable_data.dart';

void main() {
  const day = '2026-09-19';
  final journalInstant = DateTime(2026, 9, 19, 12, 30);

  JournalEntry makeJournalEntry({
    String id = 'j1',
    DateTime? at,
    String text = 'lunch note',
  }) => JournalEntry(
    id: id,
    at: at ?? journalInstant,
    text: text,
  );

  NutritionEntry makeMeal({
    String id = 'm1',
    String journalId = 'j1',
    String recordDay = day,
    double kcal = 500,
    bool confirmed = true,
  }) => NutritionEntry(
    id: id,
    journalEntryId: journalId,
    day: recordDay,
    label: 'Meal',
    kcal: kcal,
    confirmed: confirmed,
  );

  ActivityEntry makeActivity({
    String id = 'a1',
    String journalId = 'j1',
    String recordDay = day,
    double kcal = 350,
    double? minutes,
    bool confirmed = true,
  }) => ActivityEntry(
    id: id,
    journalEntryId: journalId,
    day: recordDay,
    label: 'Run',
    kcal: kcal,
    minutes: minutes,
    confirmed: confirmed,
  );

  group('PathEvent pure resolver — intake validation', () {
    test('null/invalid/pending/nonpositive intake = no mark', () {
      final journal = [makeJournalEntry()];

      // 1. Pending (unconfirmed) meal
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-pending', confirmed: false)],
        ),
        isEmpty,
        reason: 'Pending intake must produce no mark',
      );

      // 2. Zero kcal
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-zero', kcal: 0)],
        ),
        isEmpty,
        reason: 'Zero kcal intake must produce no mark',
      );

      // 3. Negative kcal
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-neg', kcal: -150)],
        ),
        isEmpty,
        reason: 'Negative kcal intake must produce no mark',
      );

      // 4. NaN kcal
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-nan', kcal: double.nan)],
        ),
        isEmpty,
        reason: 'NaN kcal intake must produce no mark',
      );

      // 5. Infinite kcal
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-inf', kcal: double.infinity)],
        ),
        isEmpty,
        reason: 'Infinite kcal intake must produce no mark',
      );

      // 6. Orphaned meal (parent journal entry does not exist)
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-orphan', journalId: 'missing-parent')],
        ),
        isEmpty,
        reason: 'Orphaned intake without journal anchor must produce no mark',
      );

      // 7. Wrong civil day
      expect(
        resolvePathEvents(
          day: day,
          journal: journal,
          nutrition: [makeMeal(id: 'm-diff-day', recordDay: '2026-09-18')],
        ),
        isEmpty,
        reason: 'Intake on a different civil day must produce no mark',
      );

      // 8. Valid confirmed meal produces exactly one mark
      final validEvents = resolvePathEvents(
        day: day,
        journal: journal,
        nutrition: [makeMeal(id: 'm-valid', kcal: 600)],
      );
      expect(validEvents, hasLength(1));
      expect(validEvents.first.recordId, 'm-valid');
      expect(validEvents.first.kind, PathEventKind.intake);
      expect(validEvents.first.kcal, 600);
    });
  });

  group('Honesty invariants', () {
    test('entry-timestamp marks stay log-anchored labeled', () {
      final loggedAt = DateTime(2026, 9, 19, 14, 15, 30);
      final journal = [makeJournalEntry(at: loggedAt)];
      final meals = [makeMeal(id: 'm1', kcal: 450)];
      final activities = [makeActivity(id: 'a1', minutes: 30)];

      final events = resolvePathEvents(
        day: day,
        journal: journal,
        nutrition: meals,
        activities: activities,
      );

      expect(events, hasLength(2));
      for (final ev in events) {
        expect(ev.timestamp, loggedAt);
        expect(ev.timestampBasis, PathTimestampBasis.logAnchored);
        expect(ev.isLogAnchored, isTrue);
        expect(ev.basisLabel, 'Log-anchored');
      }
    });

    test('unknown duration NEVER gets invented length', () {
      final journal = [makeJournalEntry()];

      // Intake never has a duration
      final mealEvents = resolvePathEvents(
        day: day,
        journal: journal,
        nutrition: [makeMeal(kcal: 500)],
      );
      expect(mealEvents.single.duration, isNull);

      // Activity with null minutes
      final actNullMin = resolvePathEvents(
        day: day,
        journal: journal,
        activities: [makeActivity(minutes: null)],
      );
      expect(actNullMin.single.duration, isNull);

      // Activity with non-positive or invalid minutes
      final actZeroMin = resolvePathEvents(
        day: day,
        journal: journal,
        activities: [makeActivity(minutes: 0)],
      );
      expect(actZeroMin.single.duration, isNull);

      final actNegMin = resolvePathEvents(
        day: day,
        journal: journal,
        activities: [makeActivity(minutes: -20)],
      );
      expect(actNegMin.single.duration, isNull);

      // Activity with known positive duration
      final actKnown = resolvePathEvents(
        day: day,
        journal: journal,
        activities: [makeActivity(minutes: 45)],
      );
      expect(actKnown.single.duration, const Duration(minutes: 45));
    });

    test('daily HC totals cannot yield timed events', () {
      const dailyHcData = WearableDailyData(
        caloriesBurned: 2350.0,
        steps: 10450,
        activeMinutes: 65.0,
        restingHr: 58,
      );

      // Daily totals without timed sessions must never produce path events
      final events = resolveDailyHcTotalsToPathEvents(dailyHcData, day);
      expect(events, isEmpty);

      // Also null data
      expect(resolveDailyHcTotalsToPathEvents(null, day), isEmpty);
    });
  });

  group('Store integration', () {
    test('resolvePathEventsFromStore reads confirmed records in chronological order', () {
      final store = AppStore.memory();
      store.journal.addAll([
        makeJournalEntry(id: 'j1', at: DateTime(2026, 9, 19, 8, 0)),
        makeJournalEntry(id: 'j2', at: DateTime(2026, 9, 19, 13, 0)),
      ]);
      store.nutrition.addAll([
        makeMeal(id: 'm1', journalId: 'j1', kcal: 350, confirmed: true),
        makeMeal(id: 'm2', journalId: 'j2', kcal: 650, confirmed: true),
        makeMeal(id: 'm3', journalId: 'j2', kcal: 200, confirmed: false), // pending
      ]);
      store.activities.add(
        makeActivity(id: 'a1', journalId: 'j1', minutes: 30, confirmed: true),
      );

      final events = resolvePathEventsFromStore(store, day);
      expect(events, hasLength(3));

      // Sorted chronologically: 08:00 (intake m1, burn a1), then 13:00 (intake m2)
      expect(events[0].recordId, 'm1');
      expect(events[0].kind, PathEventKind.intake);

      expect(events[1].recordId, 'a1');
      expect(events[1].kind, PathEventKind.burn);
      expect(events[1].duration, const Duration(minutes: 30));

      expect(events[2].recordId, 'm2');
      expect(events[2].kind, PathEventKind.intake);

      store.dispose();
    });
  });
}
