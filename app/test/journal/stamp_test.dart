import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/journal/stamp.dart';

void main() {
  test('a 24h clock prefix stamps and strips', () {
    final s = stampJournalLine('7:30 ran 5k');
    expect(s.text, 'ran 5k');
    expect(s.hour, 7);
    expect(s.minute, 30);
    final at = s.apply(DateTime(2026, 9, 6, 22, 10));
    expect(at, DateTime(2026, 9, 6, 7, 30));
  });

  test('at 8am and 8:30pm are twelve-hour clocks', () {
    final morning = stampJournalLine('at 8am ate oatmeal');
    expect(morning.text, 'ate oatmeal');
    expect(morning.hour, 8);
    expect(morning.minute, 0);

    final evening = stampJournalLine('8:30pm gym 45 min');
    expect(evening.text, 'gym 45 min');
    expect(evening.hour, 20);
    expect(evening.minute, 30);
  });

  test('durations and sleep clocks are not stamps', () {
    expect(stampJournalLine('slept 7h poorly').hour, isNull);
    expect(stampJournalLine('ran 5k in 24:30').hour, isNull);
    expect(stampJournalLine('slept 23:10-6:45').hour, isNull);
    expect(stampJournalLine('bench 80x5x3').text, 'bench 80x5x3');
  });

  test('noon and midnight stamp the page', () {
    final noon = stampJournalLine('at noon ate oatmeal');
    expect(noon.text, 'ate oatmeal');
    expect(noon.hour, 12);
    expect(noon.minute, 0);

    final night = stampJournalLine('midnight ran 5k');
    expect(night.text, 'ran 5k');
    expect(night.hour, 0);
    expect(night.minute, 0);

    final spoken = stampJournalLine('this morning 7:30 ran 5k');
    expect(spoken.text, 'ran 5k');
    expect(spoken.hour, 7);
    expect(spoken.minute, 30);
  });

  test('a time of day without a clock still stamps the page', () {
    final morning = stampJournalLine('this morning ran 5k');
    expect(morning.text, 'ran 5k');
    expect(morning.hour, 8);
    expect(morning.minute, 0);

    final lunch = stampJournalLine('for lunch ate schabowy');
    expect(lunch.text, 'ate schabowy');
    expect(lunch.hour, 13);

    final rano = stampJournalLine('wczoraj rano owsianka');
    expect(rano.text, 'owsianka');
    expect(rano.daysBack, 1);
    expect(rano.hour, 8);
    expect(rano.apply(DateTime(2026, 9, 7, 22, 0)), DateTime(2026, 9, 6, 8, 0));
  });

  test('a reverted page puts the clock back on the prose', () {
    final line = draftFromStamp(
      at: DateTime(2026, 9, 6, 7, 30),
      text: 'ran 5k',
      now: DateTime(2026, 9, 6, 22, 10),
    );
    expect(line, '7:30 ran 5k');
    final again = stampJournalLine(line);
    expect(again.text, 'ran 5k');
    expect(again.hour, 7);
    expect(again.minute, 30);
  });

  test('yesterday moves the page back one civil day', () {
    final s = stampJournalLine('yesterday ran 5k');
    expect(s.text, 'ran 5k');
    expect(s.daysBack, 1);
    final at = s.apply(DateTime(2026, 9, 7, 8, 15));
    expect(at, DateTime(2026, 9, 6, 8, 15));

    final clock = stampJournalLine('yesterday 7:30 ran 5k');
    expect(clock.text, 'ran 5k');
    expect(clock.hour, 7);
    expect(
      clock.apply(DateTime(2026, 9, 7, 22, 0)),
      DateTime(2026, 9, 6, 7, 30),
    );

    final draft = draftFromStamp(
      at: DateTime(2026, 9, 6, 7, 30),
      text: 'ran 5k',
      now: DateTime(2026, 9, 7, 8, 0),
    );
    expect(draft, 'yesterday 7:30 ran 5k');
  });
}
