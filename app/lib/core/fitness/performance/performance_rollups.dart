import '../../db/records.dart';
import '../../db/store.dart';
import '../../health/rollups.dart';
import 'performance_models.dart';

RollingVolumeBaseline computeRollingVolume(
  AppStore store,
  String day, {
  int windowDays = 28,
}) {
  final targetDate = dayKeyDate(day);
  final startDate = targetDate.subtract(Duration(days: windowDays - 1));

  final todaySets = store.sets.where((s) => s.day == day);
  double? todayVolume = todaySets.isEmpty
      ? null
      : todaySets.fold<double>(0, (a, s) => a + s.volumeKg);

  var totalWindowVolume = 0.0;
  var trainingDays = 0;

  var cursor = startDate;
  while (!cursor.isAfter(targetDate)) {
    final d = dayKey(cursor);
    final daySets = store.sets.where((s) => s.day == d);
    if (daySets.isNotEmpty) {
      final vol = daySets.fold<double>(0, (a, s) => a + s.volumeKg);
      if (vol > 0) {
        totalWindowVolume += vol;
        trainingDays++;
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  final double? dailyMean = trainingDays > 0
      ? totalWindowVolume / windowDays
      : null;
  final double? trainingDayMean = trainingDays > 0
      ? totalWindowVolume / trainingDays
      : null;

  double? ratio;
  if (todayVolume != null && trainingDayMean != null && trainingDayMean > 0) {
    ratio = todayVolume / trainingDayMean;
  }

  return RollingVolumeBaseline(
    day: day,
    windowDays: windowDays,
    todayVolumeKg: todayVolume,
    totalWindowVolumeKg: trainingDays > 0 ? totalWindowVolume : null,
    dailyMeanVolumeKg: dailyMean,
    trainingDaysCount: trainingDays,
    trainingDayMeanVolumeKg: trainingDayMean,
    volumeRatioVsBaseline: ratio,
  );
}

RollingStrainBaseline computeRollingStrain(
  AppStore store,
  String day, {
  int windowDays = 28,
}) {
  final targetDate = dayKeyDate(day);
  final summary = store.summaryOn(day);

  final todayStrain = summary?.strain;
  final todayLoad = dailyLoad(store, day);

  var acuteLoadSum = 0.0;
  var chronicLoadSum = 0.0;
  var strainSum = 0.0;
  var strainCount = 0;

  for (var i = 0; i < windowDays; i++) {
    final d = dayKey(targetDate.subtract(Duration(days: i)));
    final load = dailyLoad(store, d);
    chronicLoadSum += load;
    if (i < 7) {
      acuteLoadSum += load;
    }
    final s = store.summaryOn(d);
    if (s?.strain != null) {
      strainSum += s!.strain!;
      strainCount++;
    }
  }

  final acuteMean = acuteLoadSum / 7.0;
  final chronicMean = chronicLoadSum / windowDays.toDouble();
  final double? acwr = (chronicMean > 0.01) ? acuteMean / chronicMean : null;
  final double? meanStrain = strainCount > 0 ? strainSum / strainCount : null;

  return RollingStrainBaseline(
    day: day,
    windowDays: windowDays,
    todayStrain: todayStrain,
    todayLoad: todayLoad > 0 ? todayLoad : null,
    acute7DayMeanLoad: acuteMean > 0 ? acuteMean : null,
    chronic28DayMeanLoad: chronicMean > 0 ? chronicMean : null,
    acuteToChronicWorkloadRatio: acwr,
    rolling28DayStrainMean: meanStrain,
  );
}

List<ExerciseOneRmBaseline> computeExerciseOneRmBaselines(
  AppStore store,
  String day,
) {
  final targetDate = dayKeyDate(day);
  final startDate28 = targetDate.subtract(const Duration(days: 28));

  final exerciseIds = <String>{};
  final exerciseNames = <String, String>{};
  for (final s in store.sets) {
    exerciseIds.add(s.exerciseId);
    exerciseNames[s.exerciseId] = s.exerciseName;
  }

  final out = <ExerciseOneRmBaseline>[];
  for (final id in exerciseIds) {
    double? todayEpley;
    double? todayBrzycki;
    double? prevBestEpley;
    double? prevBestBrzycki;
    double? allTimeEpley;
    double? allTimeBrzycki;
    double? rolling28BestEpley;

    for (final s in store.sets) {
      if (s.exerciseId != id) continue;
      final e1rm = s.epley1rm;
      final b1rm = s.brzycki1rm;
      if (e1rm == null) continue;

      if (allTimeEpley == null || e1rm > allTimeEpley) allTimeEpley = e1rm;
      if (b1rm != null && (allTimeBrzycki == null || b1rm > allTimeBrzycki)) {
        allTimeBrzycki = b1rm;
      }

      if (s.day == day) {
        if (todayEpley == null || e1rm > todayEpley) todayEpley = e1rm;
        if (b1rm != null && (todayBrzycki == null || b1rm > todayBrzycki)) {
          todayBrzycki = b1rm;
        }
      } else if (s.day.compareTo(day) < 0) {
        if (prevBestEpley == null || e1rm > prevBestEpley) {
          prevBestEpley = e1rm;
        }
        if (b1rm != null &&
            (prevBestBrzycki == null || b1rm > prevBestBrzycki)) {
          prevBestBrzycki = b1rm;
        }
      }

      final sDate = dayKeyDate(s.day);
      if (!sDate.isBefore(startDate28) && !sDate.isAfter(targetDate)) {
        if (rolling28BestEpley == null || e1rm > rolling28BestEpley) {
          rolling28BestEpley = e1rm;
        }
      }
    }

    out.add(
      ExerciseOneRmBaseline(
        exerciseId: id,
        name: exerciseNames[id] ?? id,
        todayEpleyKg: todayEpley,
        todayBrzyckiKg: todayBrzycki,
        previousBestEpleyKg: prevBestEpley,
        previousBestBrzyckiKg: prevBestBrzycki,
        allTimeBestEpleyKg: allTimeEpley,
        allTimeBestBrzyckiKg: allTimeBrzycki,
        rolling28DayBestEpleyKg: rolling28BestEpley,
      ),
    );
  }

  out.sort((a, b) {
    final aVal = a.todayEpleyKg ?? 0;
    final bVal = b.todayEpleyKg ?? 0;
    if (bVal != aVal) return bVal.compareTo(aVal);
    return (b.allTimeBestEpleyKg ?? 0).compareTo(a.allTimeBestEpleyKg ?? 0);
  });
  return out;
}

PerformanceRollup computePerformanceRollup(AppStore store, String day) {
  return PerformanceRollup(
    day: day,
    volume: computeRollingVolume(store, day),
    strain: computeRollingStrain(store, day),
    lifts: computeExerciseOneRmBaselines(store, day),
  );
}
