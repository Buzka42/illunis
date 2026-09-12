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
