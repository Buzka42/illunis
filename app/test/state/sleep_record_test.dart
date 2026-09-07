import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/state/sleep_record.dart';

void main() {
  test('mock night covers the window with contiguous segments', () {
    final r = SleepRecord.mock(startHours: -0.83, endHours: 6.77);
    expect(r.segments.first.startHours, closeTo(-0.83, 1e-9));
    expect(r.segments.last.endHours, closeTo(6.77, 1e-9));
    for (var i = 1; i < r.segments.length; i++) {
      expect(
        r.segments[i].startHours,
        closeTo(r.segments[i - 1].endHours, 1e-9),
      );
    }
    expect(r.asleepHours, lessThan(r.durationHours));
    expect(r.asleepHours, greaterThan(r.durationHours * 0.8));
    expect(r.segments.any((s) => s.stage == SleepStage.deep), isTrue);
    expect(r.segments.any((s) => s.stage == SleepStage.rem), isTrue);
  });

  test('a night that starts after midnight has no negative hours', () {
    final r = SleepRecord.mock(startHours: 1.35, endHours: 6.1, seed: 3);
    expect(r.segments.every((s) => s.startHours >= 0), isTrue);
  });
}
