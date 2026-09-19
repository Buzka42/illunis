import '../db/records.dart';
import '../db/store.dart';
import '../sky/sky_state.dart';

/// Civil-day fraction of a timestamp. The timeline is one turn of the clock.
double timeOfDayFraction(DateTime at) {
  final millis =
      (at.hour * 3600 + at.minute * 60 + at.second) * 1000 + at.millisecond;
  return (millis / 86400000.0).clamp(0.0, 1.0);
}

/// One hairline per journal page on [day], in clock order. Kind is not
/// drawn — the track is a scale, not a legend.
List<double> timelineMarksOn(AppStore store, String day) {
  final marks = <double>[
    for (final e in store.journal)
      if (e.day == day) timeOfDayFraction(e.at),
  ]..sort();
  return marks;
}

/// Confirmed food (intake) and activity (burn) dots along the diurnal path.
/// Matches timeline calorie dots positioning and weights.
List<SkyPathDot> skyPathDotsOn(AppStore store, String day) {
  final entries = <String, JournalEntry>{
    for (final entry in store.journal)
      if (entry.day == day) entry.id: entry,
  };
  final totals = <(String, bool), double>{};
  void add(
    String id,
    String recordDay,
    double kcal,
    bool confirmed,
    bool isIntake,
  ) {
    if (!confirmed ||
        recordDay != day ||
        !entries.containsKey(id) ||
        !kcal.isFinite ||
        kcal <= 0) {
      return;
    }
    final key = (id, isIntake);
    final sum = (totals[key] ?? 0) + kcal;
    if (sum.isFinite) totals[key] = sum;
  }

  for (final meal in store.nutrition) {
    add(
      meal.journalEntryId,
      meal.day,
      meal.kcal,
      meal.confirmed,
      true,
    );
  }
  for (final activity in store.activities) {
    add(
      activity.journalEntryId,
      activity.day,
      activity.kcal,
      activity.confirmed,
      false,
    );
  }
  return [
    for (final item in totals.entries)
      SkyPathDot(
        timeOfDay: timeOfDayFraction(entries[item.key.$1]!.at),
        weight: (item.value / 1000).clamp(0.0, 1.0),
        isIntake: item.key.$2,
      ),
  ]..sort((a, b) {
    final time = a.timeOfDay.compareTo(b.timeOfDay);
    return time != 0 ? time : (a.isIntake ? 0 : 1).compareTo(b.isIntake ? 0 : 1);
  });
}

