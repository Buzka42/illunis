import '../db/records.dart';
import '../db/store.dart';

/// Best estimated 1RM (Epley) per exercise on a day, with the prior best
/// so the dashboard can show a delta instead of a streak cartoon.
class LiftBest {
  const LiftBest({
    required this.exerciseId,
    required this.name,
    required this.epleyKg,
    this.previousKg,
  });

  final String exerciseId;
  final String name;
  final double epleyKg;
  final double? previousKg;

  double? get deltaKg => previousKg == null ? null : epleyKg - previousKg!;
}

List<LiftBest> bestLiftsOn(AppStore store, String day) {
  final best = <String, StrengthSet>{};
  for (final s in store.sets) {
    if (s.day != day || s.epley1rm == null) continue;
    final cur = best[s.exerciseId];
    if (cur == null || s.epley1rm! > (cur.epley1rm ?? 0)) {
      best[s.exerciseId] = s;
    }
  }
  final out = <LiftBest>[];
  for (final s in best.values) {
    double? prev;
    for (final o in store.sets) {
      if (o.exerciseId != s.exerciseId) continue;
      if (o.day.compareTo(day) >= 0) continue;
      if (o.epley1rm == null) continue;
      if (prev == null || o.epley1rm! > prev) prev = o.epley1rm;
    }
    out.add(
      LiftBest(
        exerciseId: s.exerciseId,
        name: s.exerciseName,
        epleyKg: s.epley1rm!,
        previousKg: prev,
      ),
    );
  }
  out.sort((a, b) => b.epleyKg.compareTo(a.epleyKg));
  return out;
}

String liftLabel(String name) {
  final n = name.toUpperCase();
  if (n.contains('BENCH')) return 'BENCH';
  if (n.contains('SQUAT')) return 'SQUAT';
  if (n.contains('DEADLIFT')) return 'DEADLIFT';
  if (n.contains('OVERHEAD') || n.contains('SHOULDER PRESS')) {
    return 'PRESS';
  }
  if (n.contains('ROW')) return 'ROW';
  if (n.contains('PULL')) return 'PULL-UP';
  if (n.length <= 10) return n;
  return n.substring(0, 9);
}
