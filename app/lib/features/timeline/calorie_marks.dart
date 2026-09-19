import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/db/store.dart';
import '../../core/journal/marks.dart';
import '../../core/sky/sky_state.dart';
import '../../core/state/app_providers.dart';

enum CalorieKind { intake, burn }

/// Confirmed energy at its journal timestamp, not an invented meal time.
class CalorieMark {
  const CalorieMark(this.time, this.kcal, this.kind);

  final double time;
  final double kcal;
  final CalorieKind kind;

  double get weight => (kcal / 1000).clamp(0.0, 1.0);
  double get radius => 1.25 + 1.75 * weight;
  double get alpha => 0.4 + 0.5 * weight;
}

extension CalorieMarkToSky on CalorieMark {
  SkyPathDot toSkyPathDot() => SkyPathDot(
    timeOfDay: time,
    weight: weight,
    isIntake: kind == CalorieKind.intake,
  );
}

final calorieMarksProvider = Provider.family<List<CalorieMark>, String>((
  ref,
  day,
) {
  ref.watch(storeRevisionProvider);
  return calorieMarksOn(ref.watch(storeProvider), day);
});

List<CalorieMark> calorieMarksOn(AppStore store, String day) {
  final entries = <String, JournalEntry>{
    for (final entry in store.journal)
      if (entry.day == day) entry.id: entry,
  };
  final totals = <(String, CalorieKind), double>{};
  void add(
    String id,
    String recordDay,
    double kcal,
    bool confirmed,
    CalorieKind kind,
  ) {
    if (!confirmed ||
        recordDay != day ||
        !entries.containsKey(id) ||
        !kcal.isFinite ||
        kcal <= 0) {
      return;
    }
    final key = (id, kind);
    final sum = (totals[key] ?? 0) + kcal;
    if (sum.isFinite) totals[key] = sum;
  }

  for (final meal in store.nutrition) {
    add(
      meal.journalEntryId,
      meal.day,
      meal.kcal,
      meal.confirmed,
      CalorieKind.intake,
    );
  }
  for (final activity in store.activities) {
    add(
      activity.journalEntryId,
      activity.day,
      activity.kcal,
      activity.confirmed,
      CalorieKind.burn,
    );
  }
  return [
    for (final item in totals.entries)
      CalorieMark(
        timeOfDayFraction(entries[item.key.$1]!.at),
        item.value,
        item.key.$2,
      ),
  ]..sort((a, b) {
    final time = a.time.compareTo(b.time);
    return time != 0 ? time : a.kind.index.compareTo(b.kind.index);
  });
}
