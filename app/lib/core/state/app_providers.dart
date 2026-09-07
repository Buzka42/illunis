import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../ai/transport.dart';
import '../db/records.dart';
import '../db/store.dart';
import '../fitness/progress.dart';
import '../health/local_sky_source.dart';
import '../health/rollups.dart';
import '../journal/marks.dart';
import '../journal/repository.dart';
import '../patterns/sweep.dart';
import '../strength/progress.dart';
import 'sky_state_source.dart';

final storeProvider = Provider<AppStore>((ref) {
  final store = AppStore.memory();
  ref.onDispose(store.dispose);
  return store;
});

final storeRevisionProvider = NotifierProvider<StoreRevisionNotifier, int>(
  StoreRevisionNotifier.new,
);

class StoreRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final store = ref.watch(storeProvider);
    void bump() => state++;
    store.addListener(bump);
    ref.onDispose(() => store.removeListener(bump));
    return 0;
  }
}

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.watch(storeProvider), transport: AiTransport());
});

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final journalDayProvider = NotifierProvider<JournalDayNotifier, DateTime>(
  JournalDayNotifier.new,
);

class JournalDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void prev() => state = state.subtract(const Duration(days: 1));

  void next() {
    final today = dateOnly(DateTime.now());
    final n = state.add(const Duration(days: 1));
    if (!n.isAfter(today)) state = n;
  }

  void go(DateTime d) {
    final day = dateOnly(d);
    final today = dateOnly(DateTime.now());
    if (day.isAfter(today)) return;
    state = day;
  }
}

/// Prose parked on the writing line after REVERT, so a correction is not a retype.
class JournalDraft {
  const JournalDraft(this.text, {this.keepLocal = false});
  final String text;
  final bool keepLocal;
}

final journalDraftProvider =
    NotifierProvider<JournalDraftNotifier, JournalDraft?>(
      JournalDraftNotifier.new,
    );

class JournalDraftNotifier extends Notifier<JournalDraft?> {
  @override
  JournalDraft? build() => null;

  void offer(JournalDraft draft) => state = draft;

  void clear() => state = null;
}

/// Production wiring: clock + rollups from the on-device store.
List<Override> illunisOverrides(AppStore store) {
  return [
    storeProvider.overrideWith((ref) => store),
    skyStateSourceProvider.overrideWith((ref) {
      final source = LocalSkyStateSource(store);
      ref.onDispose(source.dispose);
      return source;
    }),
  ];
}

class TodayFigures {
  const TodayFigures({
    required this.day,
    this.summary,
    this.sleep,
    this.unconfirmed = const [],
    this.unconfirmedActs = const [],
    this.findings = const [],
    this.lifts = const [],
    this.sessions = const [],
    this.insightWait,
    this.insightNote,
    this.weightKg,
    this.entryCount = 0,
    this.weekSleepHours,
    this.weekIntakeKcal,
    this.weekVolumeKg,
    this.weekDistanceKm,
  });

  final String day;
  final DaySummary? summary;
  final SleepEntry? sleep;
  final List<NutritionEntry> unconfirmed;
  final List<ActivityEntry> unconfirmedActs;
  final List<PatternFinding> findings;
  final List<LiftBest> lifts;
  final List<SessionFigure> sessions;
  final PairCoverage? insightWait;
  final String? insightNote;
  final double? weightKg;
  final int entryCount;
  final double? weekSleepHours;
  final double? weekIntakeKcal;
  final double? weekVolumeKg;
  final double? weekDistanceKm;
}

TodayFigures _figures(AppStore store, String day) {
  SleepEntry? sleep;
  for (final s in store.sleeps) {
    if (s.day == day && s.isComplete) sleep = s;
  }
  if (day == dayKey(DateTime.now())) sleep ??= store.lastSleep();
  final week = weekRollup(store, day);
  final board = insightBoard(store.summaries);
  return TodayFigures(
    day: day,
    summary: store.summaryOn(day),
    sleep: sleep,
    unconfirmed: [
      for (final e in store.nutrition)
        if (!e.confirmed && e.day == day) e,
    ],
    unconfirmedActs: [
      for (final e in store.activities)
        if (!e.confirmed && e.day == day) e,
    ],
    findings: board.findings,
    insightWait: board.closest,
    insightNote: store.insightNote,
    lifts: bestLiftsOn(store, day),
    sessions: sessionsOn(store, day),
    weightKg: store.weightOnOrBefore(day),
    entryCount: store.journal.where((e) => e.day == day).length,
    weekSleepHours: week.sleepHours,
    weekIntakeKcal: week.intakeKcal,
    weekVolumeKg: week.volumeKg,
    weekDistanceKm: week.distanceKm,
  );
}

final todayFiguresProvider = Provider<TodayFigures>((ref) {
  ref.watch(storeRevisionProvider);
  return _figures(ref.watch(storeProvider), dayKey(DateTime.now()));
});

final journalFiguresProvider = Provider<TodayFigures>((ref) {
  ref.watch(storeRevisionProvider);
  final day = dayKey(ref.watch(journalDayProvider));
  return _figures(ref.watch(storeProvider), day);
});

final journalEntriesProvider = Provider<List<JournalEntry>>((ref) {
  ref.watch(storeRevisionProvider);
  final store = ref.watch(storeProvider);
  final day = dayKey(ref.watch(journalDayProvider));
  return store.entriesOn(day);
});

/// Kept so older tests keep compiling.
final todayEntriesProvider = journalEntriesProvider;

/// Journal pages on the civil day the sky timeline represents (today).
final timelineMarksProvider = Provider<List<double>>((ref) {
  ref.watch(storeRevisionProvider);
  return timelineMarksOn(ref.watch(storeProvider), dayKey(DateTime.now()));
});
