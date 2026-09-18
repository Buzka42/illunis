import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/patterns/progressive.dart';
import 'package:illunis/core/wearables/wearable_data.dart';

DaySummary _day(String day,
        {double? sleep, int? steps, double? move, double? strain}) =>
    DaySummary(
        day: day,
        sleepHours: sleep,
        steps: steps,
        moveMinutes: move,
        strain: strain);

void main() {
  test('days 1-6 emit a coverage letter only', () {
    final days = [
      for (var i = 0; i < 6; i++)
        _day('2026-04-0${i + 1}', sleep: 7.0 + i * 0.1, steps: 4000 + i * 200),
    ];
    final letters = progressiveLetters(days: days);
    expect(letters, hasLength(1));
    expect(letters.single.id, 'coverage');
    expect(letters.single.text, contains('6 days logged'));
    expect(letters.single.text, contains('21 paired days'));
    expect(letters.single.text.length, lessThanOrEqualTo(140));
  });

  test('end of week 1 emits descriptive ranges, never correlation', () {
    final days = [
      for (var i = 0; i < 7; i++)
        _day('2026-04-0${i + 1}',
            sleep: 6.2 + (i % 4) * 0.5, steps: 3100 + i * 700),
    ];
    final letters = progressiveLetters(days: days);
    expect(letters, isNotEmpty);
    for (final l in letters) {
      expect(l.text.length, lessThanOrEqualTo(140));
      expect(l.text.toLowerCase(), isNot(contains('you')));
      expect(l.text.toLowerCase(), isNot(contains('your')));
      expect(l.text.toLowerCase(), isNot(contains('because')));
      expect(l.text.toLowerCase(), isNot(contains('should')));
    }
    expect(letters.any((l) => l.id == 'week1-steps'), isTrue);
    expect(letters.any((l) => l.id == 'week1-sleep'), isTrue);
    // No direction notes with only 7 values.
    expect(letters.any((l) => l.id.startsWith('trend-')), isFalse);
  });

  test('weeks 2-3 direction notes carry the uncertainty label', () {
    final days = [
      for (var i = 0; i < 14; i++)
        _day('2026-04-${(i + 1).toString().padLeft(2, '0')}',
            sleep: 7.0, steps: 3000 + i * 400),
    ];
    final letters = progressiveLetters(days: days);
    final trends = letters.where((l) => l.id.startsWith('trend-')).toList();
    expect(trends, isNotEmpty);
    for (final t in trends) {
      expect(t.text, contains('early, uncertain'));
      expect(t.text.length, lessThanOrEqualTo(140));
    }
    // Flat sleep series: no fake direction.
    expect(trends.any((l) => l.id == 'trend-sleep'), isFalse);
  });

  test('wearables-only path works with no journal at all', () {
    final wearable = {
      for (var i = 0; i < 7; i++)
        '2026-05-0${i + 1}': WearableDailyData(
            steps: 5000 + i * 300, sleepHours: 6.5 + (i % 3) * 0.4),
    };
    final letters = progressiveLetters(days: const [], wearable: wearable);
    expect(letters, isNotEmpty);
    expect(letters.any((l) => l.id == 'week1-steps'), isTrue);
    expect(letters.any((l) => l.id == 'week1-sleep'), isTrue);
  });

  test('day 21+ with real findings stays silent (sweep path owns it)', () {
    final days = [
      for (var i = 0; i < 28; i++)
        DaySummary(
          day: '2026-02-${(i + 1).toString().padLeft(2, '0')}',
          sleepHours: 6 + (i % 7) * 0.3,
          runSpeedKmh: 9.5 + (i % 7) * 0.4 + i * 0.01,
        ),
    ];
    expect(progressiveLetters(days: days), isEmpty);
  });

  test('empty history stays silent', () {
    expect(progressiveLetters(days: const []), isEmpty);
  });
}
