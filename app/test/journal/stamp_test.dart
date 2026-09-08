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
    expect(stampJournalLine('went to bed at 23:10').hour, isNull);
    expect(
      stampJournalLine('went to bed at 23:10').text,
      'went to bed at 23:10',
    );
    expect(stampJournalLine('woke at 6:45').hour, isNull);
    expect(stampJournalLine('woke at 6:45').text, 'woke at 6:45');
    expect(
      stampJournalLine('fell asleep at 23:10').text,
      'fell asleep at 23:10',
    );
    expect(stampJournalLine('up at 6:45').text, 'up at 6:45');
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

  test('a trailing time of day stamps the same as a leading one', () {
    final morning = stampJournalLine('ran 5k this morning');
    expect(morning.text, 'ran 5k');
    expect(morning.hour, 8);

    final eve = stampJournalLine('gym 45 in the evening');
    expect(eve.text, 'gym 45');
    expect(eve.hour, 19);

    final at = stampJournalLine('ate oatmeal at 8am');
    expect(at.text, 'ate oatmeal');
    expect(at.hour, 8);

    final meal = stampJournalLine('ate oatmeal for breakfast');
    expect(meal.text, 'ate oatmeal');
    expect(meal.hour, 8);

    final around = stampJournalLine('around 7:30 ran 5k');
    expect(around.text, 'ran 5k');
    expect(around.hour, 7);
    expect(around.minute, 30);

    final commaClock = stampJournalLine('7,30 ran 5k');
    expect(commaClock.text, 'ran 5k');
    expect(commaClock.hour, 7);
    expect(commaClock.minute, 30);

    final y = stampJournalLine('ran 5k yesterday');
    expect(y.text, 'ran 5k');
    expect(y.daysBack, 1);

    final both = stampJournalLine('7:30 ran 5k yesterday');
    expect(both.text, 'ran 5k');
    expect(both.hour, 7);
    expect(both.daysBack, 1);

    expect(stampJournalLine('ran 5k in 24:30').hour, isNull);
    expect(stampJournalLine('ate lunch').hour, isNull);

    final na = stampJournalLine('na śniadanie owsianka');
    expect(na.text, 'owsianka');
    expect(na.hour, 8);

    final trailNa = stampJournalLine('owsianka na śniadanie');
    expect(trailNa.text, 'owsianka');
    expect(trailNa.hour, 8);

    final last = stampJournalLine('last night ate pizza');
    expect(last.text, 'ate pizza');
    expect(last.daysBack, 1);

    final trailNight = stampJournalLine('ran 5k last night');
    expect(trailNight.text, 'ran 5k');
    expect(trailNight.daysBack, 1);

    final nightSleep = stampJournalLine('last night slept 7h');
    expect(nightSleep.text, 'slept 7h');
    expect(nightSleep.daysBack, 0);
    expect(nightSleep.hour, isNull);

    final wNocyPizza = stampJournalLine('w nocy zjadłem pizzę');
    expect(wNocyPizza.text, 'zjadłem pizzę');
    expect(wNocyPizza.daysBack, 1);

    final wNocySen = stampJournalLine('w nocy spałem 7h');
    expect(wNocySen.text, 'spałem 7h');
    expect(wNocySen.daysBack, 0);

    final dzisiajRano = stampJournalLine('dzisiaj rano ran 5k');
    expect(dzisiajRano.text, 'ran 5k');
    expect(dzisiajRano.hour, 8);

    final wPoludnie = stampJournalLine('w południe obiad');
    expect(wPoludnie.text, 'obiad');
    expect(wPoludnie.hour, 12);

    final oPolnocy = stampJournalLine('o północy spacer');
    expect(oPolnocy.text, 'spacer');
    expect(oPolnocy.hour, 0);

    final dotClock = stampJournalLine('7:30 ran 5k.');
    expect(dotClock.text, 'ran 5k');
    expect(dotClock.hour, 7);
    expect(dotClock.minute, 30);

    final polozylem = stampJournalLine('położyłem się o 23:10');
    expect(polozylem.hour, isNull);
    expect(polozylem.text, 'położyłem się o 23:10');
  });
}
