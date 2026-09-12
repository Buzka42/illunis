import 'dart:math' as math;

import '../db/records.dart';
import '../db/store.dart';
import 'digest.dart';

/// Rebuild daily figures from the record. Vitals stay null until the
/// underlying measurements exist — a rest day with a log is 0 strain; a
/// day nobody wrote in is unknown. Unconfirmed food and activity never
/// enter totals; pending work leaves strain unknown rather than calling
/// the day rest.
Future<void> recomputeSummaries(AppStore store, {Set<String>? days}) async {
  final today = dayKey(DateTime.now());
  final Set<String> targetDays;
  if (days == null || days.isEmpty) {
    targetDays = _allDays(store);
  } else {
    final sorted = days.toList()..sort();
    final earliest = dayKeyDate(sorted.first);
    final todayDate = dayKeyDate(today);
    targetDays = <String>{};
    var cursor = earliest;
    while (!cursor.isAfter(todayDate)) {
      targetDays.add(dayKey(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
  }
  targetDays.add(today);
  final ordered = targetDays.toList()..sort();
  await store.transaction(() async {
    for (final d in ordered) {
      if (d.compareTo(today) > 0) continue;
      await store.putSummary(_summaryFor(store, d));
    }
  });
}

Set<String> _allDays(AppStore store) {
  final s = <String>{};
  for (final e in store.journal) {
    s.add(e.day);
  }
  for (final e in store.sleeps) {
    s.add(e.day);
  }
  for (final e in store.sets) {
    s.add(e.day);
  }
  for (final e in store.nutrition) {
    s.add(e.day);
  }
  for (final e in store.activities) {
    s.add(e.day);
  }
  for (final e in store.weights) {
    s.add(e.day);
  }
  for (final e in store.steps) {
    s.add(e.day);
  }
  return s;
}

/// Computes an AI-eligible summary for [day], strictly filtering out any entry
/// that is marked KEEP LOCAL (excludedFromAi == true) or whose source entry is missing.
DaySummary summaryForAi(AppStore store, String day) {
  return _summaryFor(store, day, forAi: true);
}

double dailyLoad(AppStore store, String day, {bool forAi = false}) {
  final sets = store.sets.where(
    (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
  );
  final acts = store.activities.where(
    (e) =>
        e.day == day &&
        e.confirmed &&
        (!forAi || store.isAiEligible(e.journalEntryId)),
  );
  final volume = sets.fold<double>(0, (a, s) => a + s.volumeKg);
  final actKcal = acts.fold<double>(0, (a, s) => a + s.kcal);
  return volume / 1000.0 + actKcal / 400.0;
}

DaySummary _summaryFor(AppStore store, String day, {bool forAi = false}) {
  final hasLog =
      store.journal.any((e) => e.day == day && (!forAi || !e.excludedFromAi)) ||
      store.sleeps.any(
        (e) => e.day == day && (!forAi || store.isSleepAiEligible(e)),
      ) ||
      store.sets.any(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      ) ||
      store.nutrition.any(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      ) ||
      store.activities.any(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      ) ||
      store.weights.any(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      ) ||
      store.steps.any(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      );
  if (!hasLog) {
    return DaySummary(day: day);
  }

  final sleeps = store.sleeps
      .where(
        (e) =>
            e.day == day &&
            e.isComplete &&
            (!forAi || store.isSleepAiEligible(e)),
      )
      .toList();
  final sets = store.sets
      .where(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      )
      .toList();
  final foods = store.nutrition
      .where(
        (e) =>
            e.day == day &&
            e.confirmed &&
            (!forAi || store.isAiEligible(e.journalEntryId)),
      )
      .toList();
  final acts = store.activities
      .where(
        (e) =>
            e.day == day &&
            e.confirmed &&
            (!forAi || store.isAiEligible(e.journalEntryId)),
      )
      .toList();
  final pendingWork = store.activities.any(
    (e) =>
        e.day == day &&
        !e.confirmed &&
        (!forAi || store.isAiEligible(e.journalEntryId)),
  );

  double? sleepHours;
  if (sleeps.isNotEmpty) {
    sleepHours = sleeps.fold<double>(0, (a, s) => a + s.durationHours);
  }

  final sleepScore = _sleepScore(store, day, sleeps, sleepHours, forAi: forAi);
  final recovery = sleepScore == null
      ? null
      : (0.35 + 0.65 * sleepScore).clamp(0.0, 1.0);

  final nSets = sets.fold<int>(0, (a, s) => a + s.sets);
  final volume = sets.fold<double>(0, (a, s) => a + s.volumeKg);
  final load = dailyLoad(store, day, forAi: forAi);
  final trained = sets.isNotEmpty || acts.isNotEmpty;
  final strain = trained
      ? _strain(store, day, load, nSets + acts.length, forAi: forAi)
      : (pendingWork ? null : 0.0);

  double? intake;
  double? protein;
  double? carbs;
  double? fat;
  if (foods.isNotEmpty) {
    intake = foods.fold<double>(0, (a, s) => a + s.kcal);
    protein = foods.fold<double>(0, (a, s) => a + (s.proteinG ?? 0));
    carbs = foods.fold<double>(0, (a, s) => a + (s.carbsG ?? 0));
    fat = foods.fold<double>(0, (a, s) => a + (s.fatG ?? 0));
  }

  WeightEntry? bestWeight;
  for (final w in store.weights) {
    if (w.day.compareTo(day) <= 0 &&
        (!forAi || store.isAiEligible(w.journalEntryId))) {
      if (bestWeight == null || w.day.compareTo(bestWeight.day) >= 0) {
        bestWeight = w;
      }
    }
  }
  final weight = bestWeight?.kg;

  final confirmedActivityKcal = acts.fold<double>(0, (a, s) => a + s.kcal);
  final gymLogged = acts.any((a) => a.disciplineId == 'gym');
  final liftHours = nSets * 2.5 / 60.0;
  final liftKcal = (weight == null || nSets == 0 || gymLogged)
      ? 0.0
      : 6.0 * weight * liftHours;
  final movementKcal = confirmedActivityKcal + liftKcal;
  final expenditure = weight == null
      ? (movementKcal <= 0 ? null : movementKcal)
      : 22.0 * weight + movementKcal;

  double? best1rm;
  for (final s in sets) {
    final v = s.epley1rm;
    if (v == null) continue;
    if (best1rm == null || v > best1rm) best1rm = v;
  }

  double? moveMinutes;
  double? distanceKm;
  double? runSpeed;
  if (acts.isNotEmpty) {
    moveMinutes = acts.fold<double>(0, (a, s) => a + (s.minutes ?? 0));
    if (moveMinutes <= 0) moveMinutes = null;
    distanceKm = acts.fold<double>(0, (a, s) => a + (s.distanceKm ?? 0));
    if (distanceKm <= 0) distanceKm = null;
    for (final a in acts) {
      if (a.disciplineId != 'run') continue;
      if (a.distanceKm == null || a.minutes == null || a.minutes! <= 0) {
        continue;
      }
      final kmh = a.distanceKm! / (a.minutes! / 60.0);
      if (runSpeed == null || kmh > runSpeed) runSpeed = kmh;
    }
  }

  final daySteps = store.steps
      .where(
        (e) => e.day == day && (!forAi || store.isAiEligible(e.journalEntryId)),
      )
      .toList();
  final int? steps = daySteps.isEmpty
      ? null
      : daySteps.fold<int>(0, (a, s) => a + s.steps);

  final energy = _energy(store, day, intake, expenditure, forAi: forAi);
  final todayDelta = intake != null && expenditure != null
      ? intake - expenditure
      : null;
  final prev = store.summaryOn(day);
  final built = DaySummary(
    day: day,
    sleepHours: sleepHours,
    sleepScore: sleepScore,
    recovery: recovery,
    strain: strain,
    intakeKcal: intake,
    expenditureKcal: expenditure,
    energyBalance: energy.$1,
    energyKcal: energy.$2 ?? todayDelta,
    sets: sets.isEmpty ? null : nSets,
    volumeKg: sets.isEmpty ? null : volume,
    proteinG: foods.isEmpty ? null : protein,
    carbsG: foods.isEmpty ? null : carbs,
    fatG: foods.isEmpty ? null : fat,
    best1rmKg: best1rm,
    moveMinutes: moveMinutes,
    distanceKm: distanceKm,
    runSpeedKmh: runSpeed,
    steps: steps,
  );
  if (forAi) return built;
  final keepAi = prev?.digestSource == 'ai' && (prev?.digest ?? '').isNotEmpty;
  if (keepAi) {
    return built.copyWith(digest: prev!.digest, digestSource: 'ai');
  }
  final local = composeDayDigest(store, day, built);
  return built.copyWith(
    digest: local,
    digestSource: local == null ? null : 'local',
  );
}

double? _sleepScore(
  AppStore store,
  String day,
  List<SleepEntry> sleeps,
  double? hours, {
  bool forAi = false,
}) {
  if (hours == null) return null;
  final windowStart = dayKeyDate(day).subtract(const Duration(days: 30));
  final recent =
      store.sleeps
          .where(
            (e) =>
                e.isComplete &&
                e.day.compareTo(dayKey(windowStart)) >= 0 &&
                e.day.compareTo(day) <= 0 &&
                (!forAi || store.isSleepAiEligible(e)),
          )
          .map((e) => e.durationHours)
          .toList()
        ..sort();
  final target = recent.length >= 5 ? _median(recent) : 7.5;
  final duration = (hours / target).clamp(0.0, 1.0);
  double timing = 1;
  if (sleeps.isNotEmpty && recent.length >= 3) {
    final starts =
        store.sleeps
            .where(
              (e) =>
                  e.isComplete &&
                  e.day.compareTo(dayKey(windowStart)) >= 0 &&
                  e.day.compareTo(day) <= 0 &&
                  (!forAi || store.isSleepAiEligible(e)),
            )
            .map((e) => e.startHours)
            .toList()
          ..sort();
    final medianStart = _median(starts);
    final delta = (sleeps.first.startHours - medianStart).abs();
    timing = (1 - delta / 3).clamp(0.0, 1.0);
  }
  var score = (0.75 * duration + 0.25 * timing).clamp(0.0, 1.0);
  var qSum = 0.0;
  var qn = 0;
  for (final s in sleeps) {
    if (s.quality == null) continue;
    qSum += s.quality!;
    qn++;
  }
  if (qn > 0) {
    score = (0.55 * score + 0.45 * (qSum / qn)).clamp(0.0, 1.0);
  }
  return score;
}

double? _strain(
  AppStore store,
  String day,
  double load,
  int loggedWork, {
  bool forAi = false,
}) {
  if (loggedWork == 0 && load == 0) {
    return 0;
  }
  final start = dayKeyDate(day).subtract(const Duration(days: 28));
  final loads = <double>[];
  var cursor = start;
  final dayDate = dayKeyDate(day);
  while (cursor.isBefore(dayDate)) {
    final k = dayKey(cursor);
    final pastLoad = dailyLoad(store, k, forAi: forAi);
    if (pastLoad > 0) {
      loads.add(pastLoad);
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  loads.add(load);
  if (loads.where((l) => l > 0).isEmpty) {
    return load > 0 ? 1 : 0;
  }
  final p90 = _percentile(loads, 0.9);
  if (p90 <= 0) return load > 0 ? 1 : 0;
  return (load / p90).clamp(0.0, 1.0);
}

(double?, double?) _energy(
  AppStore store,
  String day,
  double? intakeToday,
  double? expenditureToday, {
  bool forAi = false,
}) {
  final start = dayKeyDate(day).subtract(const Duration(days: 6));
  var missingIntake = 0;
  final deltas = <double>[];
  for (var i = 0; i < 7; i++) {
    final d = dayKey(start.add(Duration(days: i)));
    final s = d == day
        ? null
        : (forAi ? summaryForAi(store, d) : store.summaryOn(d));
    final intake = d == day ? intakeToday : s?.intakeKcal;
    final exp = d == day ? expenditureToday : s?.expenditureKcal;
    if (intake == null) {
      missingIntake++;
      continue;
    }
    if (exp == null) continue;
    deltas.add(intake - exp);
  }
  if (missingIntake >= 3 || deltas.isEmpty) return (null, null);
  final mean = deltas.reduce((a, b) => a + b) / deltas.length;
  return (_tanh(mean / 600).clamp(-1.0, 1.0), mean);
}

double _median(List<double> xs) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : 0.5 * (s[m - 1] + s[m]);
}

double _percentile(List<double> xs, double p) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  if (s.length == 1) return s.first;
  final i = (p * (s.length - 1)).clamp(0, s.length - 1);
  final lo = i.floor();
  final hi = i.ceil();
  if (lo == hi) return s[lo];
  final t = i - lo;
  return s[lo] * (1 - t) + s[hi] * t;
}

double _tanh(double x) {
  if (x > 20) return 1;
  if (x < -20) return -1;
  final e2 = math.exp(2 * x);
  return (e2 - 1) / (e2 + 1);
}

/// Means over the seven days ending on [day], ignoring missing values.
class WeekRollup {
  const WeekRollup({
    this.sleepHours,
    this.intakeKcal,
    this.volumeKg,
    this.distanceKm,
  });
  final double? sleepHours;
  final double? intakeKcal;
  final double? volumeKg;
  final double? distanceKm;

  bool get isEmpty =>
      sleepHours == null &&
      intakeKcal == null &&
      volumeKg == null &&
      distanceKm == null;
}

WeekRollup weekRollup(AppStore store, String day) {
  final end = dayKeyDate(day);
  var sleepSum = 0.0, sleepN = 0;
  var intakeSum = 0.0, intakeN = 0;
  var volSum = 0.0, volN = 0;
  var distSum = 0.0, distN = 0;
  for (var i = 0; i < 7; i++) {
    final s = store.summaryOn(dayKey(end.subtract(Duration(days: i))));
    if (s?.sleepHours != null) {
      sleepSum += s!.sleepHours!;
      sleepN++;
    }
    if (s?.intakeKcal != null) {
      intakeSum += s!.intakeKcal!;
      intakeN++;
    }
    if (s?.volumeKg != null) {
      volSum += s!.volumeKg!;
      volN++;
    }
    if (s?.distanceKm != null) {
      distSum += s!.distanceKm!;
      distN++;
    }
  }
  return WeekRollup(
    sleepHours: sleepN == 0 ? null : sleepSum / sleepN,
    intakeKcal: intakeN == 0 ? null : intakeSum / intakeN,
    volumeKg: volN == 0 ? null : volSum / volN,
    distanceKm: distN == 0 ? null : distSum / distN,
  );
}
