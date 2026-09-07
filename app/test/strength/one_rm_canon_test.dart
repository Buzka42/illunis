import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/strength/canon.dart';
import 'package:illunis/core/strength/one_rm.dart';

void main() {
  test('Epley and Brzycki agree at one rep and refuse high reps', () {
    expect(epley1rm(100, 1), 100);
    expect(brzycki1rm(100, 1), 100);
    expect(epley1rm(80, 5), closeTo(80 * (1 + 5 / 30), 1e-9));
    expect(brzycki1rm(80, 5), closeTo(80 * 36 / 32, 1e-9));
    expect(epley1rm(80, 11), isNull);
    expect(brzycki1rm(80, 11), isNull);
  });

  test('alias hits and Jaro–Winkler recovers a misspelling', () {
    expect(resolveExercise('bench').exercise?.id, 'barbell-bench-press');
    expect(resolveExercise('rdl').exercise?.id, 'romanian-deadlift');
    final fuzzy = resolveExercise('barbell bench pres');
    expect(fuzzy.unknown, isFalse);
    expect(fuzzy.exercise?.id, 'barbell-bench-press');
    expect(jaroWinkler('bench press', 'bench press'), 1);
    expect(jaroWinkler('bench', 'benchh'), greaterThan(0.88));
  });

  test('unknown names stay typed', () {
    final r = resolveExercise('no such lift');
    expect(r.unknown, isTrue);
    expect(r.name, 'no such lift');
  });
}
