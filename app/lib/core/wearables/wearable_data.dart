import 'package:flutter/foundation.dart';

import '../state/sleep_record.dart';

/// A single stage span within a wearable sleep session.
@immutable
class WearableSleepStage {
  const WearableSleepStage({
    required this.start,
    required this.end,
    required this.stage,
  });

  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  Map<String, Object?> toJson() => {
    'startTime': start.toIso8601String(),
    'endTime': end.toIso8601String(),
    'stage': stage.name,
  };

  factory WearableSleepStage.fromJson(Map<String, Object?> j) {
    final startStr = (j['startTime'] ?? j['start']) as String;
    final endStr = (j['endTime'] ?? j['end']) as String;
    final rawStage = j['stage'];
    final SleepStage parsedStage;
    if (rawStage is int) {
      parsedStage = switch (rawStage) {
        5 => SleepStage.deep,
        6 => SleepStage.rem,
        1 || 3 || 7 => SleepStage.awake,
        _ => SleepStage.light,
      };
    } else {
      final s = rawStage?.toString().toLowerCase() ?? 'light';
      parsedStage = switch (s) {
        'deep' => SleepStage.deep,
        'rem' => SleepStage.rem,
        'awake' => SleepStage.awake,
        _ => SleepStage.light,
      };
    }
    return WearableSleepStage(
      start: DateTime.parse(startStr),
      end: DateTime.parse(endStr),
      stage: parsedStage,
    );
  }
}

/// Data received from a wearable device (e.g. Android Health Connect).
/// Every field is nullable; unobserved figures remain null (no estimations).
@immutable
class WearableDailyData {
  const WearableDailyData({
    this.steps,
    this.sleepHours,
    this.restingHr,
    this.activeMinutes,
    this.caloriesBurned,
    this.sleepStart,
    this.sleepEnd,
    this.sleepStages = const [],
  });

  final int? steps;
  final double? sleepHours;
  final int? restingHr;
  final double? activeMinutes;
  final double? caloriesBurned;
  final DateTime? sleepStart;
  final DateTime? sleepEnd;
  final List<WearableSleepStage> sleepStages;

  bool get isEmpty =>
      steps == null &&
      sleepHours == null &&
      restingHr == null &&
      activeMinutes == null &&
      caloriesBurned == null &&
      sleepStart == null &&
      sleepEnd == null &&
      sleepStages.isEmpty;

  Map<String, Object?> toJson() => {
    'steps': steps,
    'sleepHours': sleepHours,
    'restingHr': restingHr,
    'activeMinutes': activeMinutes,
    'caloriesBurned': caloriesBurned,
    if (sleepStart != null) 'sleepStart': sleepStart!.toIso8601String(),
    if (sleepEnd != null) 'sleepEnd': sleepEnd!.toIso8601String(),
    if (sleepStages.isNotEmpty)
      'sleepStages': sleepStages.map((s) => s.toJson()).toList(),
  };

  factory WearableDailyData.fromJson(Map<String, Object?> j) {
    final stagesRaw = j['sleepStages'] as List?;
    final stages = stagesRaw != null
        ? [
            for (final s in stagesRaw)
              if (s is Map)
                WearableSleepStage.fromJson(Map<String, Object?>.from(s)),
          ]
        : const <WearableSleepStage>[];
    return WearableDailyData(
      steps: (j['steps'] as num?)?.toInt(),
      sleepHours: (j['sleepHours'] as num?)?.toDouble(),
      restingHr: (j['restingHr'] as num?)?.toInt(),
      activeMinutes: (j['activeMinutes'] as num?)?.toDouble(),
      caloriesBurned: (j['caloriesBurned'] as num?)?.toDouble(),
      sleepStart: j['sleepStart'] != null
          ? DateTime.tryParse(j['sleepStart'] as String)
          : null,
      sleepEnd: j['sleepEnd'] != null
          ? DateTime.tryParse(j['sleepEnd'] as String)
          : null,
      sleepStages: stages,
    );
  }
}

/// Health Connect package name of the Garmin Connect Mobile writer.
const String garminConnectPackage = 'com.garmin.android.apps.connectmobile';

/// Single-source rule for same-day passive step snapshots, mirroring the
/// native readDay aggregation (MainActivity.kt): the HC aggregate sums every
/// writer (Garmin + phone counter), so collapse per-origin totals to one
/// figure — Garmin first, else the max single package. Journal manual lines
/// are handled separately (journal-first in store.authoritativeSteps) and
/// never enter this map.
int? pickSingleSourceSteps(Map<String, int> stepsByOriginPackage) {
  if (stepsByOriginPackage.isEmpty) return null;
  final garmin = stepsByOriginPackage[garminConnectPackage];
  if (garmin != null) return garmin;
  return stepsByOriginPackage.values.reduce((a, b) => a > b ? a : b);
}

/// Attributes whole sleep sessions to the civil day they end on (morning
/// attribution, the Garmin Connect convention), mirroring native readDay:
/// a 23:00 -> 07:00 night counts fully toward the morning day, never split.
/// [day] is `yyyy-MM-dd` in device-local time. Returns null when no session
/// ends that day; capped at 24h.
double? sleepHoursEndingOnDay(
  List<({DateTime start, DateTime end})> sessions,
  String day,
) {
  var secs = 0;
  var attributed = 0;
  for (final s in sessions) {
    final e = s.end.toLocal();
    final endDay =
        '${e.year.toString().padLeft(4, '0')}-'
        '${e.month.toString().padLeft(2, '0')}-'
        '${e.day.toString().padLeft(2, '0')}';
    if (endDay == day) {
      secs += s.end.difference(s.start).inSeconds;
      attributed++;
    }
  }
  if (attributed == 0) return null;
  return (secs / 3600.0).clamp(0.0, 24.0);
}
