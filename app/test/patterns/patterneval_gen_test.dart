// Eval v2 generator: 3 synthetic 25-day datasets through the REAL sweep.
// Run: flutter test test/patterns/patterneval_gen_test.dart
// Writes genuine findings to /tmp/illunis-patterneval/findings.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/patterns/sweep.dart';

List<DaySummary> _athlete(int seed, double Function(int i, Random r) sleep,
    double Function(double s, int i, Random r) run, String prefix) {
  final r = Random(seed);
  return [
    for (var i = 0; i < 25; i++)
      DaySummary(
        day: '2026-$prefix-${(i + 1).toString().padLeft(2, '0')}',
        sleepHours: sleep(i, r),
        runSpeedKmh: run(sleep(i, r), i, r),
      ),
  ];
}

void main() {
  test('generate eval findings through the real sweep', () {
    final sets = <String, List<DaySummary>>{
      // A: steady sleeper, pace tracks sleep tightly.
      'A-sleep-run-tight': _athlete(7, (i, r) => 6.0 + (i % 5) * 0.45,
          (s, i, r) => 9.0 + (s - 6.0) * 0.9 + r.nextDouble() * 0.15, '06'),
      // B: erratic sleep, pace tracks sleep loosely (noisier).
      'B-sleep-run-noisy': _athlete(21, (i, r) => 5.5 + r.nextDouble() * 3.0,
          (s, i, r) => 8.6 + (s - 5.5) * 0.55 + r.nextDouble() * 0.5, '07'),
      // C: short nights pair with heavier training volume (negative dir).
      'C-sleep-volume': [
        for (var i = 0; i < 25; i++)
          DaySummary(
            day: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
            sleepHours: 5.8 + (i % 6) * 0.4,
            volumeKg: 9000 - (i % 6) * 1100 + (i % 3) * 150,
          ),
      ],
      // D: protein tracks recovery across 25 days.
      'D-protein-recovery': [
        for (var i = 0; i < 25; i++)
          DaySummary(
            day: '2026-09-${(i + 1).toString().padLeft(2, '0')}',
            proteinG: 90 + (i % 5) * 18.0 + (i % 3) * 7,
            recovery: 0.45 + (i % 5) * 0.09 + (i % 4) * 0.015,
          ),
      ],
    };
    final out = <String, Object?>{};
    for (final e in sets.entries) {
      final found = sweepPatterns(e.value);
      out[e.key] = [
        for (final f in found)
          {
            'id': f.id,
            'pairLabel': f.pairLabel,
            'localSentence': f.sentence,
            'n': f.correlation.n,
            'r': double.parse(f.correlation.r.toStringAsFixed(3)),
            'p': f.correlation.p,
            'evidence': f.evidence,
          },
      ];
    }
    Directory('/tmp/illunis-patterneval').createSync(recursive: true);
    File('/tmp/illunis-patterneval/findings.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
    // At least one set must produce a genuine finding or the eval is void.
    expect(
        out.values.any((v) => (v as List).isNotEmpty), isTrue,
        reason: 'no synthetic set survived the real sweep');
  });
}
