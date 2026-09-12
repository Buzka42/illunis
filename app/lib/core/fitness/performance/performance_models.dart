import 'package:flutter/foundation.dart';

/// 1RM evaluation for one exercise, comparing today vs prior baselines.
/// Follows absence honesty: null when no lift was performed.
@immutable
class ExerciseOneRmBaseline {
  const ExerciseOneRmBaseline({
    required this.exerciseId,
    required this.name,
    this.todayEpleyKg,
    this.todayBrzyckiKg,
    this.previousBestEpleyKg,
    this.previousBestBrzyckiKg,
    this.allTimeBestEpleyKg,
    this.allTimeBestBrzyckiKg,
    this.rolling28DayBestEpleyKg,
  });

  final String exerciseId;
  final String name;

  /// Today's best Epley 1RM. Null if not lifted today.
  final double? todayEpleyKg;

  /// Today's best Brzycki 1RM. Null if not lifted today.
  final double? todayBrzyckiKg;

  /// Best 1RM prior to today.
  final double? previousBestEpleyKg;
  final double? previousBestBrzyckiKg;

  /// All-time best 1RM including today.
  final double? allTimeBestEpleyKg;
  final double? allTimeBestBrzyckiKg;

  /// Rolling 28-day peak 1RM.
  final double? rolling28DayBestEpleyKg;

  /// Delta against prior best Epley 1RM (positive = PR / progression).
  double? get deltaEpleyKg =>
      (todayEpleyKg != null && previousBestEpleyKg != null)
      ? todayEpleyKg! - previousBestEpleyKg!
      : null;
}

/// Rolling volume baseline over a multi-day window (default 28 days).
@immutable
class RollingVolumeBaseline {
  const RollingVolumeBaseline({
    required this.day,
    required this.windowDays,
    this.todayVolumeKg,
    this.totalWindowVolumeKg,
    this.dailyMeanVolumeKg,
    this.trainingDaysCount = 0,
    this.trainingDayMeanVolumeKg,
    this.volumeRatioVsBaseline,
  });

  final String day;
  final int windowDays;

  /// Today's total lifted volume in kg. Null if no sets were performed today.
  final double? todayVolumeKg;

  /// Total volume across the window preceding or including today.
  final double? totalWindowVolumeKg;

  /// Mean volume per day over all days in the window (including rest days).
  final double? dailyMeanVolumeKg;

  /// Number of days with training in the window.
  final int trainingDaysCount;

  /// Mean volume per training day. Null if no training days in window.
  final double? trainingDayMeanVolumeKg;

  /// Ratio of today's volume vs typical training day mean (e.g. 1.2 = 20% higher).
  final double? volumeRatioVsBaseline;
}

/// Rolling strain and workload baseline over a window (default 28 days).
/// Acute (7-day) vs Chronic (28-day) workload metrics.
@immutable
class RollingStrainBaseline {
  const RollingStrainBaseline({
    required this.day,
    required this.windowDays,
    this.todayStrain,
    this.todayLoad,
    this.acute7DayMeanLoad,
    this.chronic28DayMeanLoad,
    this.acuteToChronicWorkloadRatio,
    this.rolling28DayStrainMean,
  });

  final String day;
  final int windowDays;

  /// Today's strain (0..1). Null if unlogged or pending work.
  final double? todayStrain;

  /// Today's raw daily load. Null if no load logged.
  final double? todayLoad;

  /// 7-day rolling average load (acute workload).
  final double? acute7DayMeanLoad;

  /// 28-day rolling average load (chronic workload).
  final double? chronic28DayMeanLoad;

  /// ACWR: acute / chronic ratio (e.g. 0.8..1.3 is sweet spot; >1.5 is spike).
  /// Null if chronic workload is 0 or insufficient data.
  final double? acuteToChronicWorkloadRatio;

  /// Mean strain score across days with logs in the 28-day window.
  final double? rolling28DayStrainMean;
}

/// Consolidated performance rollup figures for display surfaces.
/// Pure store projection, absence = null / '—'.
@immutable
class PerformanceRollup {
  const PerformanceRollup({
    required this.day,
    required this.volume,
    required this.strain,
    this.lifts = const [],
  });

  final String day;
  final RollingVolumeBaseline volume;
  final RollingStrainBaseline strain;
  final List<ExerciseOneRmBaseline> lifts;
}
