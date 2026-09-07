import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/patterns/statistics.dart';
import 'package:illunis/core/patterns/sweep.dart';
import 'package:illunis/core/db/records.dart';

void main() {
  test('Pearson is high on a line and null on a constant', () {
    const xs = <double>[1, 2, 3, 4, 5, 6, 7, 8];
    const ys = <double>[1.0, 2.4, 2.8, 4.5, 4.9, 6.2, 6.7, 8.3];
    final c = correlate(xs, ys);
    expect(c, isNotNull);
    expect(c!.r, greaterThan(0.9));
    expect(c.n, 8);
    expect(correlate(xs, List.filled(8, 3)), isNull);
    expect(correlate(xs, [for (var i = 0; i < 8; i++) 2 * xs[i]]), isNull);
  });

  test('Benjamini–Hochberg keeps a strong pair and drops a weak one', () {
    final strong = const Correlation(r: 0.7, n: 30, p: 0.001);
    final weak = const Correlation(r: 0.4, n: 30, p: 0.4);
    final kept = survivingFindings([
      Candidate(subject: 'a', correlation: strong),
      Candidate(subject: 'b', correlation: weak),
    ]);
    expect(kept.map((e) => e.subject), ['a']);
  });

  test('sweep stays silent before 21 paired days', () {
    final days = [
      for (var i = 0; i < 12; i++)
        DaySummary(
          day: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          sleepHours: 7 + i / 20,
          strain: 0.2 + i / 40,
        ),
    ];
    expect(sweepPatterns(days), isEmpty);
    final board = insightBoard(days);
    expect(board.findings, isEmpty);
    expect(board.closest?.n, 12);
    expect(board.closest?.label, 'SLEEP · STRAIN');
  });

  test('sweep names a sleep–run pair and cites the observed range', () {
    final days = [
      for (var i = 0; i < 28; i++)
        DaySummary(
          day: '2026-02-${(i + 1).toString().padLeft(2, '0')}',
          sleepHours: 6 + (i % 7) * 0.3,
          runSpeedKmh: 9.5 + (i % 7) * 0.4 + i * 0.01,
        ),
    ];
    final found = sweepPatterns(days);
    expect(found, isNotEmpty);
    final run = found.firstWhere((f) => f.id == 'sleep-run');
    expect(run.evidence, isNotNull);
    expect(run.evidence, contains('h'));
    expect(run.evidence, contains('/km'));
    expect(run.correlation.n, 28);
  });

  test('sweep names a rest–run pair from sleep score', () {
    final days = [
      for (var i = 0; i < 28; i++)
        DaySummary(
          day: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
          sleepScore: 0.4 + (i % 7) * 0.08,
          runSpeedKmh: 9.2 + (i % 7) * 0.35 + i * 0.01,
        ),
    ];
    final found = sweepPatterns(days);
    final rest = found.firstWhere((f) => f.id == 'rest-run');
    expect(rest.pairLabel, 'REST · RUN');
    expect(rest.evidence, contains('/km'));
    expect(rest.correlation.n, 28);
  });
}
