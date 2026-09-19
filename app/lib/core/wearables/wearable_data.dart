import 'package:flutter/foundation.dart';

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
  });

  final int? steps;
  final double? sleepHours;
  final int? restingHr;
  final double? activeMinutes;
  final double? caloriesBurned;

  bool get isEmpty =>
      steps == null &&
      sleepHours == null &&
      restingHr == null &&
      activeMinutes == null &&
      caloriesBurned == null;

  Map<String, Object?> toJson() => {
    'steps': steps,
    'sleepHours': sleepHours,
    'restingHr': restingHr,
    'activeMinutes': activeMinutes,
    'caloriesBurned': caloriesBurned,
  };

  factory WearableDailyData.fromJson(Map<String, Object?> j) =>
      WearableDailyData(
        steps: (j['steps'] as num?)?.toInt(),
        sleepHours: (j['sleepHours'] as num?)?.toDouble(),
        restingHr: (j['restingHr'] as num?)?.toInt(),
        activeMinutes: (j['activeMinutes'] as num?)?.toDouble(),
        caloriesBurned: (j['caloriesBurned'] as num?)?.toDouble(),
      );
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
