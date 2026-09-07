/// The arithmetic that decides whether a pattern is worth telling someone.
///
/// Copied as *statistics*, not as product copy, from eter2. Illunis tests
/// many pairs; the same three gates apply: enough paired days, an effect
/// worth mentioning, and Benjamini–Hochberg across the whole sweep.
library;

import 'dart:math' as math;

class Correlation {
  const Correlation({required this.r, required this.n, required this.p});

  final double r;
  final int n;
  final double p;
  double get explainedFraction => r * r;
  bool get isPositive => r > 0;
}

Correlation? correlate(List<double> xs, List<double> ys) {
  if (xs.length != ys.length || xs.length < 3) return null;
  final n = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;
  var covariance = 0.0, varianceX = 0.0, varianceY = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    final dy = ys[i] - meanY;
    covariance += dx * dy;
    varianceX += dx * dx;
    varianceY += dy * dy;
  }
  if (varianceX <= 0 || varianceY <= 0) return null;
  final r = (covariance / math.sqrt(varianceX * varianceY)).clamp(-1.0, 1.0);
  if (r.abs() >= 0.999) return null;
  final t = r * math.sqrt((n - 2) / (1 - r * r));
  return Correlation(r: r.toDouble(), n: n, p: _twoTailedT(t.abs(), n - 2));
}

double _twoTailedT(double t, int df) {
  if (df <= 0) return 1;
  final x = df / (df + t * t);
  return _incompleteBeta(x, df / 2, 0.5).clamp(0.0, 1.0);
}

double _incompleteBeta(double x, double a, double b) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  final lnBeta = _lnGamma(a) + _lnGamma(b) - _lnGamma(a + b);
  final front = math.exp(a * math.log(x) + b * math.log(1 - x) - lnBeta);
  if (x > (a + 1) / (a + b + 2)) {
    return 1 - _incompleteBeta(1 - x, b, a);
  }
  var f = 1.0, c = 1.0, d = 0.0;
  for (var i = 0; i <= 300; i++) {
    final m = i ~/ 2;
    final double numerator;
    if (i == 0) {
      numerator = 1;
    } else if (i.isEven) {
      numerator = (m * (b - m) * x) / ((a + 2 * m - 1) * (a + 2 * m));
    } else {
      numerator =
          -((a + m) * (a + b + m) * x) / ((a + 2 * m) * (a + 2 * m + 1));
    }
    d = 1 + numerator * d;
    if (d.abs() < 1e-30) d = 1e-30;
    d = 1 / d;
    c = 1 + numerator / c;
    if (c.abs() < 1e-30) c = 1e-30;
    final delta = c * d;
    f *= delta;
    if ((1 - delta).abs() < 1e-12) break;
  }
  return front * (f - 1) / a;
}

double _lnGamma(double value) {
  const coefficients = [
    76.18009172947146,
    -86.50532032941677,
    24.01409824083091,
    -1.231739572450155,
    0.1208650973866179e-2,
    -0.5395239384953e-5,
  ];
  var y = value;
  final tmp = value + 5.5 - (value + 0.5) * math.log(value + 5.5);
  var series = 1.000000000190015;
  for (var i = 0; i < 6; i++) {
    series += coefficients[i] / ++y;
  }
  return -tmp + math.log(2.5066282746310005 * series / value);
}

class Candidate<T> {
  const Candidate({required this.subject, required this.correlation});
  final T subject;
  final Correlation correlation;
}

List<Candidate<T>> survivingFindings<T>(
  List<Candidate<T>> candidates, {
  double falseDiscoveryRate = 0.1,
  int minimumPairs = 21,
  double minimumAbsR = 0.35,
}) {
  final eligible = [
    for (final candidate in candidates)
      if (candidate.correlation.n >= minimumPairs &&
          candidate.correlation.r.abs() >= minimumAbsR)
        candidate,
  ]..sort((a, b) => a.correlation.p.compareTo(b.correlation.p));
  if (eligible.isEmpty) return const [];
  final m = eligible.length;
  var cutoff = -1;
  for (var i = 0; i < m; i++) {
    if (eligible[i].correlation.p <= (i + 1) / m * falseDiscoveryRate) {
      cutoff = i;
    }
  }
  if (cutoff < 0) return const [];
  return eligible.take(cutoff + 1).toList();
}
