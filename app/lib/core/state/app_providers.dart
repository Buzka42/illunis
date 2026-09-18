import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../ai/transport.dart';
import '../db/records.dart';
import '../db/store.dart';
import '../fitness/performance/performance_models.dart';
import '../fitness/performance/performance_rollups.dart';
import '../fitness/progress.dart';
import '../health/local_sky_source.dart';
import '../health/rollups.dart';
import '../journal/marks.dart';
import '../journal/repository.dart';
import '../patterns/sweep.dart';
import '../sky/sky_weather.dart';
import '../strength/progress.dart';
import '../wearables/health_bridge.dart';
import '../wearables/life_stats.dart';
import '../wearables/wearable_data.dart';
import '../weather/weather_model.dart';
import '../weather/weather_service.dart';
import 'sky_state_source.dart';
import 'civil_day.dart';

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
  /// True only after PREV/NEXT. A stamp that reveals yesterday is not
  /// catch-up — the next unstamped line still belongs to the clock day.
  var catchUp = false;

  @override
  DateTime build() {
    ref.listen(civilDayProvider, (previous, next) {
      if (!catchUp) state = next;
    });
    return ref.read(civilDayProvider);
  }

  void prev() {
    catchUp = true;
    state = DateTime(state.year, state.month, state.day - 1);
  }

  void next() {
    final today = dateOnly(DateTime.now());
    final n = DateTime(state.year, state.month, state.day + 1);
    if (n.isAfter(today)) return;
    catchUp = !sameDay(n, today);
    state = n;
  }

  void go(DateTime d, {bool? catchUp}) {
    final day = dateOnly(d);
    final today = dateOnly(DateTime.now());
    if (day.isAfter(today)) return;
    if (sameDay(day, today)) {
      this.catchUp = false;
    } else if (catchUp != null) {
      this.catchUp = catchUp;
    }
    state = day;
  }
}

/// Prose parked on the writing line after REVERT, so a correction is not a retype.
class JournalDraft {
  const JournalDraft(this.text, {this.keepLocal = false, this.replacesEntryId});
  final String text;
  final bool keepLocal;
  final String? replacesEntryId;
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
List<Override> illunisOverrides(
  AppStore store, {
  WeatherService? weatherService,
}) {
  final weather = weatherService ?? WeatherService();
  return [
    storeProvider.overrideWith((ref) => store),
    weatherServiceProvider.overrideWith((ref) => weather),
    skyStateSourceProvider.overrideWith((ref) {
      final source = LocalSkyStateSource(store, weatherService: weather);
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
    this.incompleteBed,
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
    this.steps,
  });

  final String day;
  final DaySummary? summary;
  final SleepEntry? sleep;
  final SleepEntry? incompleteBed;
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
  final int? steps;
}

TodayFigures _figures(AppStore store, String day, DateTime now) {
  SleepEntry? sleep;
  SleepEntry? incompleteBed;
  for (final s in store.sleeps) {
    // The night is the longest complete stretch of the day. A later short
    // nap must not shadow it: the timeline band, the nightstand, and the
    // mock sleep figure all read the night, not the nap.
    if (s.day == day && s.isComplete) {
      if (sleep == null || s.durationHours > sleep.durationHours) sleep = s;
    }
    if (!s.isComplete && s.day == day) incompleteBed = s;
  }
  final today = day == dayKey(now);
  final date = dayKeyDate(day);
  final yesterday = dayKey(DateTime(date.year, date.month, date.day - 1));
  if (today && sleep == null) {
    final latest = store.lastSleep();
    if (latest != null && (latest.day == day || latest.day == yesterday)) {
      sleep = latest;
    }
  }
  if (today && incompleteBed == null) {
    for (var i = store.sleeps.length - 1; i >= 0; i--) {
      if (!store.sleeps[i].isComplete && store.sleeps[i].day == yesterday) {
        incompleteBed = store.sleeps[i];
        break;
      }
    }
  }
  final week = weekRollup(store, day);
  final board = insightBoard(store.summaries);
  bool pendingDay(String d) => d == day || (today && d == yesterday);
  return TodayFigures(
    day: day,
    summary: store.summaryOn(day),
    sleep: sleep,
    incompleteBed: incompleteBed,
    unconfirmed: [
      for (final e in store.nutrition)
        if (!e.confirmed && pendingDay(e.day)) e,
    ],
    unconfirmedActs: [
      for (final e in store.activities)
        if (!e.confirmed && pendingDay(e.day)) e,
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
    steps: store.stepsOn(day) ?? store.summaryOn(day)?.steps,
  );
}

final todayFiguresProvider = Provider<TodayFigures>((ref) {
  ref.watch(storeRevisionProvider);
  return _figures(
    ref.watch(storeProvider),
    dayKey(ref.watch(civilDayProvider)),
    ref.watch(civilDayProvider),
  );
});

final journalFiguresProvider = Provider<TodayFigures>((ref) {
  ref.watch(storeRevisionProvider);
  final day = dayKey(ref.watch(journalDayProvider));
  return _figures(ref.watch(storeProvider), day, ref.watch(civilDayProvider));
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
  return timelineMarksOn(
    ref.watch(storeProvider),
    dayKey(ref.watch(civilDayProvider)),
  );
});

// --- Weather ---
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final service = WeatherService();
  ref.onDispose(service.dispose);
  return service;
});

final weatherObservationProvider = Provider<WeatherObservation?>((ref) {
  final service = ref.watch(weatherServiceProvider);
  return service.cachedObservation;
});

final activeSkyWeatherProvider = Provider<SkyWeather?>((ref) {
  final service = ref.watch(weatherServiceProvider);
  return service.currentSkyWeather;
});

final weather24hProjectionProvider = Provider<List<HourlyWeatherProjection>>((
  ref,
) {
  final obs = ref.watch(weatherObservationProvider);
  return obs?.hourly24h ?? const [];
});

// --- Wearables / Health Connect & Life Stats ---
final healthBridgeProvider = Provider<HealthBridge>((ref) {
  return HealthBridge.create();
});

final wearableDailyDataProvider =
    FutureProvider.family<WearableDailyData?, String>((ref, day) async {
      final bridge = ref.watch(healthBridgeProvider);
      final date = dayKeyDate(day);
      return bridge.getDailyData(date);
    });

final lifeStatsProvider = Provider.family<DailyLifeStats, String>((ref, day) {
  ref.watch(storeRevisionProvider);
  final store = ref.watch(storeProvider);
  final wearableAsync = ref.watch(wearableDailyDataProvider(day));
  final wearable = wearableAsync.value;
  return resolveLifeStats(store: store, day: day, wearable: wearable);
});

final todayLifeStatsProvider = Provider<DailyLifeStats>((ref) {
  return ref.watch(lifeStatsProvider(dayKey(ref.watch(civilDayProvider))));
});

// --- Performance Rollups ---
final performanceRollupProvider = Provider.family<PerformanceRollup, String>((
  ref,
  day,
) {
  ref.watch(storeRevisionProvider);
  final store = ref.watch(storeProvider);
  return computePerformanceRollup(store, day);
});

final todayPerformanceRollupProvider = Provider<PerformanceRollup>((ref) {
  return ref.watch(
    performanceRollupProvider(dayKey(ref.watch(civilDayProvider))),
  );
});
