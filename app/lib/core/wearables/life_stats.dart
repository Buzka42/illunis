import 'package:flutter/foundation.dart';

import '../db/store.dart';
import 'wearable_data.dart';

enum StatSource { journal, wearable, rule, ai }

@immutable
class LifeStat<T> {
  const LifeStat({required this.value, required this.source});

  const LifeStat.absent([this.source = StatSource.journal]) : value = null;

  final T? value;
  final StatSource source;

  bool get isPresent => value != null;

  @override
  bool operator ==(Object other) =>
      other is LifeStat<T> && other.value == value && other.source == source;

  @override
  int get hashCode => Object.hash(value, source);

  @override
  String toString() => 'LifeStat($value from $source)';
}

@immutable
class DailyLifeStats {
  const DailyLifeStats({
    required this.day,
    required this.caloriesBurned,
    required this.calorieIntake,
    required this.steps,
    required this.sleep,
    required this.restingHr,
    required this.activeMinutes,
    required this.restedness,
  });

  final String day;
  final LifeStat<double> caloriesBurned;
  final LifeStat<double> calorieIntake;
  final LifeStat<int> steps;
  final LifeStat<double> sleep;
  final LifeStat<int> restingHr;
  final LifeStat<double> activeMinutes;
  final LifeStat<double> restedness;
}

/// Pure resolution function to compute the 6+1 life stats.
/// Honesty rules:
/// - Journal wins ties (when both journal and wearable data exist)
/// - Absence stays null end-to-end
/// - Resting HR is wearable only (absence = null, never estimated)
/// - Calorie intake is journal only
/// - Restedness provenance labelled (ai vs rule)
DailyLifeStats resolveLifeStats({
  required AppStore store,
  required String day,
  WearableDailyData? wearable,
  double? aiRestedness,
}) {
  final summary = store.summaryOn(day);
  final profile = store.profile;

  // 1. Calories burned (expenditure)
  // Wearable OR journal-calculated. Preference or journal-wins-ties.
  LifeStat<double> caloriesBurned;
  final journalExp = summary?.expenditureKcal;
  final wearableExp = wearable?.caloriesBurned;
  if (profile.caloriesBurnedSource == 'wearable' && wearableExp != null) {
    caloriesBurned = LifeStat(value: wearableExp, source: StatSource.wearable);
  } else if (journalExp != null) {
    caloriesBurned = LifeStat(value: journalExp, source: StatSource.journal);
  } else if (wearableExp != null) {
    caloriesBurned = LifeStat(value: wearableExp, source: StatSource.wearable);
  } else {
    caloriesBurned = const LifeStat.absent(StatSource.journal);
  }

  // 2. Calorie intake — journal only
  final intake = summary?.intakeKcal;
  final calorieIntake = intake != null
      ? LifeStat<double>(value: intake, source: StatSource.journal)
      : const LifeStat<double>.absent(StatSource.journal);

  // 3. Steps — wearable/phone pedometer, plus manual journal entry
  // Journal wins ties.
  LifeStat<int> steps;
  final journalSteps = summary?.steps ?? store.stepsOn(day);
  final wearableSteps = wearable?.steps;
  if (profile.stepsSource == 'wearable' && wearableSteps != null) {
    steps = LifeStat(value: wearableSteps, source: StatSource.wearable);
  } else if (journalSteps != null) {
    steps = LifeStat(value: journalSteps, source: StatSource.journal);
  } else if (wearableSteps != null) {
    steps = LifeStat(value: wearableSteps, source: StatSource.wearable);
  } else {
    steps = const LifeStat.absent(StatSource.journal);
  }

  // 4. Sleep — wearable; journal stays the fallback and the canonical record
  // when both exist (journal wins ties — it is reviewed text).
  LifeStat<double> sleep;
  final journalSleep = summary?.sleepHours;
  final wearableSleep = wearable?.sleepHours;
  if (journalSleep != null) {
    sleep = LifeStat(value: journalSleep, source: StatSource.journal);
  } else if (wearableSleep != null) {
    sleep = LifeStat(value: wearableSleep, source: StatSource.wearable);
  } else {
    sleep = const LifeStat.absent(StatSource.journal);
  }

  // 5. Resting HR — wearable only; absence = —, never estimated.
  LifeStat<int> restingHr;
  if (wearable?.restingHr != null) {
    restingHr = LifeStat(
      value: wearable!.restingHr,
      source: StatSource.wearable,
    );
  } else {
    restingHr = const LifeStat.absent(StatSource.wearable);
  }

  // 6. Active minutes — wearable OR derived from logged sessions.
  LifeStat<double> activeMinutes;
  final journalMins = summary?.moveMinutes;
  final wearableMins = wearable?.activeMinutes;
  if (profile.activeMinutesSource == 'wearable' && wearableMins != null) {
    activeMinutes = LifeStat(value: wearableMins, source: StatSource.wearable);
  } else if (journalMins != null) {
    activeMinutes = LifeStat(value: journalMins, source: StatSource.journal);
  } else if (wearableMins != null) {
    activeMinutes = LifeStat(value: wearableMins, source: StatSource.wearable);
  } else {
    activeMinutes = const LifeStat.absent(StatSource.journal);
  }

  // 7. Restedness — AI-evaluated from sleep/training/HR (E4);
  // labelled by provenance (AI vs rule) the way MOCK/LOCAL are labelled today.
  LifeStat<double> restedness;
  if (aiRestedness != null) {
    restedness = LifeStat(value: aiRestedness, source: StatSource.ai);
  } else {
    // Rule evaluation based on recovery/sleepScore if present
    final rec = summary?.recovery;
    final rhr = wearable?.restingHr;
    if (rec != null) {
      var score = rec;
      if (rhr != null && rhr > 0) {
        // Subtle RHR influence: normal resting HR ~ 60 bpm.
        // Higher resting HR slightly discounts recovery, lower slightly enhances.
        final rhrMod = (1.0 - (rhr - 60) * 0.005).clamp(0.85, 1.15);
        score = (score * rhrMod).clamp(0.0, 1.0);
      }
      restedness = LifeStat(value: score, source: StatSource.rule);
    } else {
      restedness = const LifeStat.absent(StatSource.rule);
    }
  }

  return DailyLifeStats(
    day: day,
    caloriesBurned: caloriesBurned,
    calorieIntake: calorieIntake,
    steps: steps,
    sleep: sleep,
    restingHr: restingHr,
    activeMinutes: activeMinutes,
    restedness: restedness,
  );
}
