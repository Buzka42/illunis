import '../db/records.dart';
import '../fitness/format.dart';
import 'statistics.dart';

class PatternFinding {
  const PatternFinding({
    required this.id,
    required this.pairLabel,
    required this.sentence,
    required this.correlation,
    this.evidence,
  });

  final String id;
  final String pairLabel;
  final String sentence;
  final Correlation correlation;

  /// Min–max of the paired series, already in spoken units.
  final String? evidence;
}

class _Pair {
  _Pair(
    this.id,
    this.xLabel,
    this.yLabel,
    this.takeX,
    this.takeY,
    this.pos,
    this.neg,
  );
  final String id, xLabel, yLabel, pos, neg;
  final double? Function(DaySummary) takeX;
  final double? Function(DaySummary) takeY;
}

final _pairs = <_Pair>[
  _Pair(
    'sleep-strain',
    'sleep',
    'strain',
    (s) => s.sleepHours,
    (s) => s.strain,
    'Longer nights have gone with heavier days.',
    'Shorter nights have gone with heavier days.',
  ),
  _Pair(
    'sleep-volume',
    'sleep',
    'volume',
    (s) => s.sleepHours,
    (s) => s.volumeKg,
    'Sleep and training volume have moved together.',
    'Shorter sleep has gone with more volume.',
  ),
  _Pair(
    'sleep-energy',
    'sleep',
    'energy',
    (s) => s.sleepHours,
    (s) => s.energyBalance,
    'Longer nights have gone with a surplus.',
    'Longer nights have gone with a deficit.',
  ),
  _Pair(
    'energy-volume',
    'energy',
    'volume',
    (s) => s.energyBalance,
    (s) => s.volumeKg,
    'A surplus has gone with more volume.',
    'A deficit has gone with more volume.',
  ),
  _Pair(
    'intake-strain',
    'intake',
    'strain',
    (s) => s.intakeKcal,
    (s) => s.strain,
    'Higher intake has gone with heavier days.',
    'Lower intake has gone with heavier days.',
  ),
  _Pair(
    'protein-recovery',
    'protein',
    'recovery',
    (s) => s.proteinG,
    (s) => s.recovery,
    'More protein has gone with better recovery.',
    'More protein has gone with worse recovery.',
  ),
  _Pair(
    'recovery-strain',
    'recovery',
    'strain',
    (s) => s.recovery,
    (s) => s.strain,
    'Better recovery has gone with heavier days.',
    'Worse recovery has gone with heavier days.',
  ),
  _Pair(
    'energy-1rm',
    'energy',
    '1RM',
    (s) => s.energyBalance,
    (s) => s.best1rmKg,
    'A surplus has gone with stronger days.',
    'A deficit has gone with stronger days.',
  ),
  _Pair(
    'sleep-run',
    'sleep',
    'run',
    (s) => s.sleepHours,
    (s) => s.runSpeedKmh,
    'Longer nights have gone with faster runs.',
    'Shorter nights have gone with faster runs.',
  ),
  _Pair(
    'rest-run',
    'rest',
    'run',
    (s) => s.sleepScore,
    (s) => s.runSpeedKmh,
    'Better nights have gone with faster runs.',
    'Worse nights have gone with faster runs.',
  ),
  _Pair(
    'rest-volume',
    'rest',
    'volume',
    (s) => s.sleepScore,
    (s) => s.volumeKg,
    'Better nights have gone with more volume.',
    'Worse nights have gone with more volume.',
  ),
  _Pair(
    'sleep-distance',
    'sleep',
    'distance',
    (s) => s.sleepHours,
    (s) => s.distanceKm,
    'Longer nights have gone with more distance.',
    'Shorter nights have gone with more distance.',
  ),
  _Pair(
    'recovery-run',
    'recovery',
    'run',
    (s) => s.recovery,
    (s) => s.runSpeedKmh,
    'Better recovery has gone with faster runs.',
    'Worse recovery has gone with faster runs.',
  ),
  _Pair(
    'energy-distance',
    'energy',
    'distance',
    (s) => s.energyBalance,
    (s) => s.distanceKm,
    'A surplus has gone with more distance.',
    'A deficit has gone with more distance.',
  ),
  _Pair(
    'sleep-move',
    'sleep',
    'movement',
    (s) => s.sleepHours,
    (s) => s.moveMinutes,
    'Longer nights have gone with more movement.',
    'Shorter nights have gone with more movement.',
  ),
];

/// Honest sweep. Nothing is returned before 21 paired days survive BH.
List<PatternFinding> sweepPatterns(List<DaySummary> days) {
  final candidates = <Candidate<_Pair>>[];
  for (final pair in _pairs) {
    final xs = <double>[];
    final ys = <double>[];
    for (final d in days) {
      final x = pair.takeX(d);
      final y = pair.takeY(d);
      if (x == null || y == null) continue;
      xs.add(x);
      ys.add(y);
    }
    final c = correlate(xs, ys);
    if (c != null) {
      candidates.add(Candidate(subject: pair, correlation: c));
    }
  }
  final kept = survivingFindings(
    candidates,
    minimumPairs: 21,
    minimumAbsR: 0.35,
  );
  return [
    for (final k in kept)
      PatternFinding(
        id: k.subject.id,
        pairLabel:
            '${k.subject.xLabel.toUpperCase()} · ${k.subject.yLabel.toUpperCase()}',
        sentence: k.correlation.isPositive ? k.subject.pos : k.subject.neg,
        correlation: k.correlation,
        evidence: _evidenceFor(k.subject, days),
      ),
  ];
}

String? _evidenceFor(_Pair pair, List<DaySummary> days) {
  final xs = <double>[];
  final ys = <double>[];
  for (final d in days) {
    final x = pair.takeX(d);
    final y = pair.takeY(d);
    if (x == null || y == null) continue;
    xs.add(x);
    ys.add(y);
  }
  if (xs.length < 2) return null;
  return '${_range(pair.xLabel, xs)}  ·  ${_range(pair.yLabel, ys)}';
}

String _range(String axis, List<double> vs) {
  var lo = vs.first;
  var hi = vs.first;
  for (final v in vs) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if ((hi - lo).abs() < 1e-9) return _fmt(axis, lo);
  return '${_fmt(axis, lo)}–${_fmt(axis, hi)}';
}

String _fmt(String axis, double v) {
  switch (axis) {
    case 'sleep':
      return '${v.toStringAsFixed(1)}h';
    case 'rest':
      return '${(v * 100).round()}';
    case 'run':
      if (v <= 0) return '—';
      return '${formatPace(3600 / v)}/km';
    case 'distance':
      return '${formatKm(v)} km';
    case 'movement':
      return '${formatMinutes(v)} min';
    case 'volume':
    case '1RM':
      return '${v.round()} kg';
    case 'intake':
      return '${v.round()} kcal';
    case 'energy':
      final sign = v >= 0 ? '+' : '−';
      return '$sign${v.abs().toStringAsFixed(2)}';
    case 'protein':
      return '${v.round()} g';
    case 'strain':
    case 'recovery':
      return '${(v * 100).round()}';
    default:
      return v.toStringAsFixed(1);
  }
}

class PairCoverage {
  const PairCoverage({required this.id, required this.label, required this.n});
  final String id;
  final String label;
  final int n;
}

class InsightBoard {
  const InsightBoard({required this.findings, this.closest});
  final List<PatternFinding> findings;
  final PairCoverage? closest;
}

/// Findings that survived the gates, plus the closest pair still accumulating
/// so the empty state can be honest about how far away speech is.
InsightBoard insightBoard(List<DaySummary> days) {
  final findings = sweepPatterns(days);
  PairCoverage? closest;
  for (final pair in _pairs) {
    var n = 0;
    for (final d in days) {
      if (pair.takeX(d) != null && pair.takeY(d) != null) n++;
    }
    if (n == 0) continue;
    if (closest == null || n > closest.n) {
      closest = PairCoverage(
        id: pair.id,
        label: '${pair.xLabel.toUpperCase()} · ${pair.yLabel.toUpperCase()}',
        n: n,
      );
    }
  }
  return InsightBoard(findings: findings, closest: closest);
}
