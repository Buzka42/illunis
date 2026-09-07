import '../db/records.dart';
import '../db/store.dart';
import '../fitness/progress.dart';

/// One instrument sentence for a day. Facts only — never advice, never
/// second person. Empty when the record cannot support a sentence.
///
/// The worker may replace this later; rollups keep an AI digest until
/// then and refresh this one whenever the figures change.
String? composeDayDigest(AppStore store, String day, DaySummary s) {
  final bits = <String>[];
  final sessions = sessionsOn(store, day);
  for (final sess in sessions.take(3)) {
    final unit = sess.unit;
    bits.add(
      unit == null || unit.isEmpty
          ? '${sess.label} ${sess.value}'
          : '${sess.label} ${sess.value} · $unit',
    );
  }
  if (sessions.isEmpty && (s.sets ?? 0) > 0) {
    bits.add('${s.sets} sets');
  }
  if (s.strain == 0 && sessions.isEmpty && (s.sets ?? 0) == 0) {
    bits.add('Rest');
  }
  if (s.intakeKcal != null) {
    bits.add('Intake ${s.intakeKcal!.round()} kcal');
  }
  if (s.sleepHours != null) {
    var sleep = 'Sleep ${_dur(s.sleepHours!)}';
    SleepEntry? night;
    for (final e in store.sleeps) {
      if (e.day == day) night = e;
    }
    final q = night?.quality;
    if (q != null) {
      if (q < 0.5) {
        sleep = '$sleep, poorly';
      } else if (q >= 0.75) {
        sleep = '$sleep, well';
      }
    }
    bits.add(sleep);
  }
  if (s.energyKcal != null) {
    final k = s.energyKcal!.round();
    bits.add('Energy ${k >= 0 ? '+' : '−'}${k.abs()} kcal');
  }
  if (bits.isEmpty) return null;
  var sentence = '${bits.join('. ')}.';
  while (sentence.length > 140 && bits.length > 1) {
    bits.removeLast();
    sentence = '${bits.join('. ')}.';
  }
  if (sentence.length > 140) {
    return '${sentence.substring(0, 139).trimRight()}.';
  }
  return sentence;
}

String _dur(double h) {
  final m = (h.abs() * 60).round();
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}
