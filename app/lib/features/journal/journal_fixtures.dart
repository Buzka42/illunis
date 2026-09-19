import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/db/records.dart';
import '../../core/db/store.dart';
import '../../core/journal/dictation.dart';
import '../../core/journal/repository.dart';

/// Deterministic fixtures for journal test harnesses and presentation previews.
class JournalFixtures {
  /// 1. Empty fixture: store with 0 entries, honest empty state.
  static AppStore empty({DateTime? now}) {
    return AppStore.memory();
  }

  /// 2. Dense day fixture: 25 entries spaced across a single day for pagination.
  static AppStore denseDay({DateTime? now}) {
    final store = AppStore.memory();
    final day = now ?? DateTime.now();
    final base = DateTime(day.year, day.month, day.day, 7, 0);
    for (var i = 0; i < 25; i++) {
      final at = base.add(Duration(minutes: i * 30));
      final h = at.hour.toString().padLeft(2, '0');
      final m = at.minute.toString().padLeft(2, '0');
      store.journal.add(
        JournalEntry(
          id: 'dense-entry-$i',
          at: at,
          text: 'Entry item $i - log note at $h:$m',
        ),
      );
    }
    return store;
  }

  /// 3. Long prose fixture: entries with long paragraphs testing multiline compact truncation.
  static AppStore longProse({DateTime? now}) {
    final store = AppStore.memory();
    final day = now ?? DateTime.now();
    final at = DateTime(day.year, day.month, day.day, 8, 30);
    store.journal.add(
      JournalEntry(
        id: 'long-prose-1',
        at: at,
        text:
            'Woke up early and ran 10 kilometers around the river trail in steady rain. '
            'Felt strong throughout the middle kilometers with a brisk pace of 4:45 per km. '
            'Afterward had oatmeal with blueberries, honey, and whey protein, followed by two large espressos.',
      ),
    );
    store.journal.add(
      JournalEntry(
        id: 'long-prose-2',
        at: at.add(const Duration(hours: 4)),
        text:
            'Heavy afternoon session in the garage gym: paused bench press pyramid up to 100kg for 3 triples, '
            'followed by weighted dips and chest-supported rows with strict 90 second rest periods.',
      ),
    );
    return store;
  }

  /// 4. Mixed extractions fixture: lift, nutrition, activity, sleep, weight.
  static AppStore mixedExtractions({DateTime? now}) {
    final store = AppStore.memory();
    final day = now ?? DateTime.now();
    final dKey = dayKey(day);

    // Entry 1: Lifts
    final e1 = JournalEntry(
      id: 'entry-lift',
      at: DateTime(day.year, day.month, day.day, 10, 0),
      text: 'bench 80x5x3',
    );
    store.journal.add(e1);
    store.sets.add(
      StrengthSet(
        id: 'set-1',
        journalEntryId: e1.id,
        day: dKey,
        exerciseId: 'bench',
        exerciseName: 'Bench Press',
        weightKg: 80,
        reps: 5,
        sets: 3,
        epley1rm: 93.3,
        brzycki1rm: 90.0,
      ),
    );

    // Entry 2: Confirmed meal
    final e2 = JournalEntry(
      id: 'entry-food',
      at: DateTime(day.year, day.month, day.day, 12, 30),
      text: 'ate oatmeal',
    );
    store.journal.add(e2);
    store.nutrition.add(
      NutritionEntry(
        id: 'nut-1',
        journalEntryId: e2.id,
        day: dKey,
        label: 'Oatmeal',
        kcal: 320,
        proteinG: 12,
        confirmed: true,
      ),
    );

    // Entry 3: Confirmed activity
    final e3 = JournalEntry(
      id: 'entry-act',
      at: DateTime(day.year, day.month, day.day, 15, 0),
      text: 'ran 5k in 25m',
    );
    store.journal.add(e3);
    store.activities.add(
      ActivityEntry(
        id: 'act-1',
        journalEntryId: e3.id,
        day: dKey,
        label: 'Run',
        kcal: 360,
        minutes: 25,
        distanceKm: 5.0,
        paceSecPerKm: 300,
        confirmed: true,
      ),
    );

    // Entry 4: Sleep
    final e4 = JournalEntry(
      id: 'entry-sleep',
      at: DateTime(day.year, day.month, day.day, 7, 0),
      text: 'slept 7.5h well',
    );
    store.journal.add(e4);
    store.sleeps.add(
      SleepEntry(
        id: 'sleep-1',
        journalEntryId: e4.id,
        day: dKey,
        startHours: 23.5,
        endHours: 31.0,
        quality: 0.9,
      ),
    );

    // Entry 5: Weight
    final e5 = JournalEntry(
      id: 'entry-weight',
      at: DateTime(day.year, day.month, day.day, 7, 15),
      text: 'weighed 82.4',
    );
    store.journal.add(e5);
    store.weights.add(
      WeightEntry(
        id: 'weight-1',
        journalEntryId: e5.id,
        day: dKey,
        kg: 82.4,
      ),
    );

    return store;
  }

  /// 5. Yesterday pendings fixture: unconfirmed estimates from yesterday and today.
  static AppStore yesterdayPendings({DateTime? now}) {
    final store = AppStore.memory();
    final today = now ?? DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tKey = dayKey(today);
    final yKey = dayKey(yesterday);

    store.nutrition.add(
      NutritionEntry(
        id: 'food-yesterday',
        journalEntryId: 'j-y-1',
        day: yKey,
        label: 'pizza slice',
        kcal: 280,
        confirmed: false,
      ),
    );
    store.activities.add(
      ActivityEntry(
        id: 'act-yesterday',
        journalEntryId: 'j-y-2',
        day: yKey,
        label: 'evening walk',
        kcal: 140,
        confirmed: false,
      ),
    );
    store.nutrition.add(
      NutritionEntry(
        id: 'food-today',
        journalEntryId: 'j-t-1',
        day: tKey,
        label: 'protein shake',
        kcal: 220,
        confirmed: false,
      ),
    );
    return store;
  }

  /// 6. Edit/revert fixture: entries ready for edit and revert verification.
  static AppStore editRevert({DateTime? now}) {
    final store = AppStore.memory();
    final day = now ?? DateTime.now();
    final entry = JournalEntry(
      id: 'target-entry-1',
      at: DateTime(day.year, day.month, day.day, 14, 0),
      text: 'kawa 200ml i banan',
      excludedFromAi: true,
    );
    store.journal.add(entry);
    store.nutrition.add(
      NutritionEntry(
        id: 'derived-nut-1',
        journalEntryId: entry.id,
        day: dayKey(day),
        label: 'banan',
        kcal: 105,
        confirmed: true,
      ),
    );
    return store;
  }

  /// 7. Dictation fallback fixture: returns a failing dictation object.
  static FailingJournalDictation dictationFallback() {
    return FailingJournalDictation();
  }

  /// 8. Failed submit repository fixture: throws on log.
  static FailingJournalRepository failedSubmitRepo(
    AppStore store, {
    String error = 'Simulated write failure',
  }) {
    return FailingJournalRepository(store, error: error);
  }
}

class FailingJournalDictation implements JournalDictation {
  @override
  bool get isListening => false;

  @override
  Future<bool> start({
    required void Function(String words, bool finalResult) onWords,
    required VoidCallback onDone,
  }) async {
    return false;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class FailingJournalRepository extends JournalRepository {
  FailingJournalRepository(
    super.store, {
    this.error = 'Simulated write failure',
  });

  final String error;

  @override
  Future<JournalEntry> log(
    String text, {
    bool excludedFromAi = false,
    DateTime? at,
  }) async {
    throw Exception(error);
  }
}
