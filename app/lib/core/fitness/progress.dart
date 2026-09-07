import '../db/records.dart';
import '../db/store.dart';
import 'disciplines.dart';
import 'format.dart';

/// One discipline's figures for a day, with a delta against the prior best
/// when that comparison is honest (same metric, same sport).
class SessionFigure {
  const SessionFigure({
    required this.disciplineId,
    required this.label,
    required this.value,
    this.unit,
    this.deltaLabel,
  });

  final String disciplineId;
  final String label;
  final String value;
  final String? unit;
  final String? deltaLabel;
}

List<SessionFigure> sessionsOn(AppStore store, String day) {
  final byId = <String, List<ActivityEntry>>{};
  for (final a in store.activities) {
    if (a.day != day || !a.confirmed) continue;
    byId.putIfAbsent(a.disciplineId, () => []).add(a);
  }
  final hasLifts = store.sets.any((s) => s.day == day);
  final out = <SessionFigure>[];
  for (final e in byId.entries) {
    if (e.key == 'gym' && hasLifts) continue;
    final list = e.value;
    var km = 0.0;
    var minutes = 0.0;
    double? bestPace;
    final efforts = <String>{};
    for (final a in list) {
      km += a.distanceKm ?? 0;
      minutes += a.minutes ?? 0;
      final p = a.paceSecPerKm;
      if (p != null && (bestPace == null || p < bestPace)) bestPace = p;
      if (a.effort != null) efforts.add(a.effort!);
    }
    final effortBit = efforts.length == 1 ? efforts.single.toUpperCase() : null;
    String value;
    String? unit;
    String? deltaLabel;
    if (bestPace != null) {
      value = formatPace(bestPace);
      unit = km > 0 ? '${formatKm(km)} KM · /KM' : '/KM';
      final prev = _priorBestPace(store, e.key, day);
      if (prev != null) {
        final d = (bestPace - prev).round();
        if (d != 0) {
          deltaLabel = '${d < 0 ? '−' : '+'}${d.abs()}s';
        }
      }
    } else if (km > 0) {
      value = formatKm(km);
      unit = 'KM';
    } else if (minutes > 0) {
      value = formatMinutes(minutes);
      unit = 'MIN';
    } else {
      continue;
    }
    out.add(
      SessionFigure(
        disciplineId: e.key,
        label: disciplineLabel(e.key),
        value: value,
        unit: [?effortBit, ?deltaLabel, unit].join(' · '),
      ),
    );
  }
  out.sort((a, b) => a.label.compareTo(b.label));
  return out;
}

double? _priorBestPace(AppStore store, String disciplineId, String day) {
  double? best;
  for (final a in store.activities) {
    if (a.disciplineId != disciplineId) continue;
    if (!a.confirmed) continue;
    if (a.day.compareTo(day) >= 0) continue;
    final p = a.paceSecPerKm;
    if (p == null) continue;
    if (best == null || p < best) best = p;
  }
  return best;
}
