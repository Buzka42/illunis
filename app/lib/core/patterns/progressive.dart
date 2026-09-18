import '../db/records.dart';
import '../wearables/wearable_data.dart';
import 'sweep.dart';

/// Progressive insight schedule below the 21-day gate.
///
/// The learned sweep ([sweepPatterns]) stays silent until 21 paired days
/// survive Benjamini–Hochberg. These tiers fill the silence honestly:
///
/// | Tier | Window | What it may say | Minimum required sources |
/// |---|---|---|---|
/// | T0 coverage | 1–6 logged days | day counts + distance to 21 | ≥1 logged day (any series) |
/// | T1 descriptive | ≥7 logged days, still <21 pairs | ranges, counts, streaks | ≥4 non-null values in that series |
/// | T2 direction | same window, series with ≥8 values | raw-series direction ONLY with an uncertainty label | ≥8 non-null values, single series |
/// | T3 learned | ≥21 paired days + BH | the sweep + patternInsight reword path | unchanged |
///
/// Voice law (all tiers): ≤140 chars, no advice, no medical or causal
/// claims, no second person. T0–T2 describe one series only — never a
/// correlation between two, never a prescription.
class ProgressiveLetter {
  const ProgressiveLetter(this.id, this.text, this.provenance);
  final String id, text, provenance;
}

/// Letters for the days before the learned gate opens. Returns empty once
/// [sweepPatterns] has findings — day 21+ keeps the existing path unchanged.
List<ProgressiveLetter> progressiveLetters({
  required List<DaySummary> days,
  Map<String, WearableDailyData> wearable = const {},
}) {
  // Learned gate already open: stay out of the way.
  if (sweepPatterns(days).isNotEmpty) return const [];

  final steps = _series(days, (d) => d.steps?.toDouble(), wearable, (w) => w.steps?.toDouble());
  final sleep = _series(days, (d) => d.sleepHours, wearable, (w) => w.sleepHours);
  final move = _series(days, (d) => d.moveMinutes, wearable, (w) => w.activeMinutes);
  final rhr = _series(days, (_) => null, wearable, (w) => w.restingHr?.toDouble());

  final loggedDays = <String>{
    for (final d in days)
      if (_hasAny(d)) d.day,
    ...wearable.keys.where((k) => !(wearable[k]?.isEmpty ?? true)),
  }.length;

  // T2 direction notes need ≥8 values; T1 descriptions need ≥7 logged days.
  final t2 = <ProgressiveLetter>[
    ..._direction('steps', steps, _fmtSteps),
    ..._direction('sleep', sleep, _fmtSleep),
    ..._direction('movement', move, _fmtMinutes),
    ..._direction('resting HR', rhr, _fmtBpm),
  ];
  final t1 = <ProgressiveLetter>[
    ..._range('steps', steps, _fmtSteps),
    ..._range('sleep', sleep, _fmtSleep),
    ..._range('movement', move, _fmtMinutes),
    ..._range('resting HR', rhr, _fmtBpm),
  ];

  if (loggedDays >= 7) {
    // End of week 1: honest descriptive observations first; direction
    // notes only where a series is long enough, always labelled uncertain.
    return [...t1, ...t2];
  }
  if (loggedDays >= 1) {
    // Days 1–6: coverage only. Descriptive, never inference.
    final closest = _closestPairN(days);
    final gate = closest >= 21
        ? 'Patterns under review.'
        : 'Patterns unlock at 21 paired days.';
    final nightWord = loggedDays == 1 ? 'day' : 'days';
    return [
      ProgressiveLetter(
        'coverage',
        '$loggedDays $nightWord logged — $gate',
        'COVERAGE · LOCAL',
      ),
    ];
  }
  return const [];
}

bool _hasAny(DaySummary d) =>
    d.sleepHours != null ||
    d.sleepScore != null ||
    d.recovery != null ||
    d.strain != null ||
    d.intakeKcal != null ||
    d.expenditureKcal != null ||
    d.energyBalance != null ||
    d.sets != null ||
    d.volumeKg != null ||
    d.proteinG != null ||
    d.best1rmKg != null ||
    d.moveMinutes != null ||
    d.distanceKm != null ||
    d.runSpeedKmh != null ||
    d.steps != null;

/// One series, journal first, wearable filling gaps. Journal wins ties —
/// a reviewed line beats a sensor estimate.
List<double> _series(
  List<DaySummary> days,
  double? Function(DaySummary) takeJournal,
  Map<String, WearableDailyData> wearable,
  double? Function(WearableDailyData) takeWearable,
) {
  final out = <double>[];
  for (final d in days) {
    final j = takeJournal(d);
    if (j != null) {
      out.add(j);
      continue;
    }
    final w = wearable[d.day];
    if (w != null) {
      final v = takeWearable(w);
      if (v != null) out.add(v);
    }
  }
  // Wearable-only days with no summary row at all still count.
  for (final entry in wearable.entries) {
    if (days.any((d) => d.day == entry.key)) continue;
    final v = takeWearable(entry.value);
    if (v != null) out.add(v);
  }
  return out;
}

/// T1: range over whatever exists. Needs ≥4 values to be worth saying.
List<ProgressiveLetter> _range(
  String label,
  List<double> vs,
  String Function(double, double) fmt,
) {
  if (vs.length < 4) return const [];
  var lo = vs.first, hi = vs.first;
  for (final v in vs) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  final span = fmt(lo, hi);
  return [
    ProgressiveLetter(
      'week1-$label',
      '${_cap(label)} $span across ${vs.length} days.',
      'WEEK 1 · LOCAL',
    ),
  ];
}

/// T2: raw-series direction, second half vs first half, ONLY with the
/// uncertainty label. Needs ≥8 values. Never names another series.
List<ProgressiveLetter> _direction(
  String label,
  List<double> vs,
  String Function(double, double) fmt,
) {
  if (vs.length < 8) return const [];
  final half = vs.length ~/ 2;
  final first = vs.sublist(0, half);
  final second = vs.sublist(vs.length - half);
  double mean(List<double> l) => l.reduce((a, b) => a + b) / l.length;
  final a = mean(first), b = mean(second);
  var lo = vs.first, hi = vs.first;
  for (final v in vs) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  final spread = (hi - lo).abs();
  if (spread <= 0) return const [];
  // Less than a tenth of the observed spread moving is noise, not direction.
  if ((b - a).abs() < spread * 0.1) return const [];
  final dir = b > a ? 'upward' : 'downward';
  return [
    ProgressiveLetter(
      'trend-$label',
      '${_cap(label)} trended $dir across ${vs.length} days — early, uncertain.',
      'EARLY · LOCAL',
    ),
  ];
}

int _closestPairN(List<DaySummary> days) {
  final board = insightBoard(days);
  return board.closest?.n ?? 0;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _fmtSteps(double lo, double hi) {
  String k(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)}k'
      : v.round().toString();
  return lo == hi ? k(lo) : '${k(lo)}–${k(hi)}';
}

String _fmtSleep(double lo, double hi) {
  String h(double v) => '${v.toStringAsFixed(1)}h';
  return lo == hi ? h(lo) : '${h(lo)}–${h(hi)}';
}

String _fmtMinutes(double lo, double hi) {
  String m(double v) => '${v.round()} min';
  return lo == hi ? m(lo) : '${m(lo)}–${m(hi)}';
}

String _fmtBpm(double lo, double hi) {
  String b(double v) => '${v.round()} bpm';
  return lo == hi ? b(lo) : '${b(lo)}–${b(hi)}';
}
