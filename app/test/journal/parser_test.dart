import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/journal/parser.dart';

void main() {
  JournalEntry entry(String text) =>
      JournalEntry(id: 'e1', at: DateTime(2026, 9, 6, 18, 0), text: text);

  test('bench 80x5x3 becomes three sets of five at 80 kg', () {
    final p = parseJournal(entry('bench 80x5x3'));
    expect(p.sets, hasLength(1));
    expect(p.sets.first.exerciseName, 'Barbell bench press');
    expect(p.sets.first.weightKg, 80);
    expect(p.sets.first.reps, 5);
    expect(p.sets.first.sets, 3);
    expect(p.sets.first.epley1rm, closeTo(80 * (1 + 5 / 30), 1e-9));
  });

  test('squat 100 kg 5 reps hits the kg/reps form', () {
    final p = parseJournal(entry('squat 100 kg 5 reps'));
    expect(p.sets, hasLength(1));
    expect(p.sets.first.exerciseName, 'Barbell squat');
    expect(p.sets.first.weightKg, 100);
    expect(p.sets.first.reps, 5);
    expect(p.sets.first.sets, 1);
  });

  test('sleep clock times fold last night onto the morning', () {
    final p = parseJournal(entry('slept 23:10-6:45'));
    expect(p.sleeps, hasLength(1));
    expect(p.sleeps.first.startHours, closeTo(23 + 10 / 60 - 24, 1e-9));
    expect(p.sleeps.first.endHours, closeTo(6 + 45 / 60, 1e-9));
    expect(p.sleeps.first.durationHours, closeTo(7 + 35 / 60, 1e-6));
  });

  test('sleep duration-only assumes a 07:00 wake', () {
    final p = parseJournal(entry('slept 7h 30m'));
    expect(p.sleeps, hasLength(1));
    expect(p.sleeps.first.durationHours, closeTo(7.5, 1e-9));
    expect(p.sleeps.first.endHours, 7);
  });

  test('explicit kcal is confirmed; generic food is not', () {
    final stated = parseJournal(entry('ate chicken 450 kcal'));
    expect(stated.nutrition, hasLength(1));
    expect(stated.nutrition.first.confirmed, isTrue);
    expect(stated.nutrition.first.kcal, 450);

    final guessed = parseJournal(entry('ate oatmeal'));
    expect(guessed.nutrition, hasLength(1));
    expect(guessed.nutrition.first.confirmed, isFalse);
    expect(guessed.nutrition.first.label, 'Oatmeal');
  });

  test('weight and a run parse on one page', () {
    final p = parseJournal(entry('weighed 82.4\nran 40 min'));
    expect(p.weights.single.kg, 82.4);
    expect(p.activities, hasLength(1));
    expect(p.activities.first.label, 'Run');
    expect(p.activities.first.confirmed, isFalse);

    final spoken = parseJournal(entry('weighed in at 82.4'));
    expect(spoken.weights.single.kg, 82.4);
  });

  test('unknown prose still saves as nothing structured', () {
    final p = parseJournal(entry('felt tired after the meeting'));
    expect(p.isEmpty, isTrue);
  });

  test('unknown lift keeps the typed name', () {
    final p = parseJournal(entry('xyzzy 60x5'));
    expect(p.sets, hasLength(1));
    expect(p.sets.first.exerciseId, 'unknown');
    expect(p.sets.first.exerciseName, 'xyzzy');
  });

  test('pounds, RPE, bodyweight and prose sets parse', () {
    final lb = parseJournal(entry('bench 185 lb x5 @8'));
    expect(lb.sets, hasLength(1));
    expect(lb.sets.first.weightKg, closeTo(185 / 2.2046226218, 1e-6));
    expect(lb.sets.first.reps, 5);
    expect(lb.sets.first.rpe, 8);

    final bw = parseJournal(entry('pull-ups 8x3'));
    expect(bw.sets, hasLength(1));
    expect(bw.sets.first.weightKg, 0);
    expect(bw.sets.first.reps, 8);
    expect(bw.sets.first.sets, 3);
    expect(bw.sets.first.epley1rm, isNull);

    final push = parseJournal(entry('push-ups 20x3'));
    expect(push.sets.single.exerciseId, 'push-up');
    expect(push.sets.single.weightKg, 0);
    expect(push.sets.single.reps, 20);
    expect(push.sets.single.sets, 3);

    final count = parseJournal(entry('20 push-ups'));
    expect(count.sets.single.exerciseId, 'push-up');
    expect(count.sets.single.weightKg, 0);
    expect(count.sets.single.reps, 20);
    expect(count.sets.single.sets, 1);

    final nxnBw = parseJournal(entry('3x10 push-ups'));
    expect(nxnBw.sets.single.exerciseId, 'push-up');
    expect(nxnBw.sets.single.weightKg, 0);
    expect(nxnBw.sets.single.reps, 10);
    expect(nxnBw.sets.single.sets, 3);

    final setsOf = parseJournal(entry('3 sets of 10 pull-ups'));
    expect(setsOf.sets.single.exerciseId, 'pull-up');
    expect(setsOf.sets.single.weightKg, 0);
    expect(setsOf.sets.single.reps, 10);
    expect(setsOf.sets.single.sets, 3);

    final prose = parseJournal(entry('squat 100 kg for 5 reps'));
    expect(prose.sets, hasLength(1));
    expect(prose.sets.first.weightKg, 100);
    expect(prose.sets.first.reps, 5);
  });

  test('slept from 11 to 7 is an eight-hour night', () {
    final p = parseJournal(entry('slept from 11 to 7'));
    expect(p.sleeps, hasLength(1));
    expect(p.sleeps.first.durationHours, closeTo(8, 1e-6));

    final dash = parseJournal(entry('slept 11-7'));
    expect(dash.sleeps.first.durationHours, closeTo(8, 1e-6));

    final ampm = parseJournal(entry('slept from 11pm to 7am'));
    expect(ampm.sleeps.single.durationHours, closeTo(8, 1e-6));
  });

  test('bedtime without a wake is not a night', () {
    final p = parseJournal(entry('went to bed at 11'));
    expect(p.sleeps.single.isComplete, isFalse);
    expect(p.sleeps.single.startHours, 23);
    expect(p.sleeps.single.durationHours, 0);

    final clock = parseJournal(entry('lights out at 23:10'));
    expect(clock.sleeps.single.startHours, closeTo(23 + 10 / 60, 1e-9));
    expect(clock.sleeps.single.isComplete, isFalse);

    expect(parseJournal(entry('woke at 6:45')).sleeps, isEmpty);
  });

  test('slept poorly and slept well attach a quality', () {
    final poor = parseJournal(entry('slept 7h poorly'));
    expect(poor.sleeps, hasLength(1));
    expect(poor.sleeps.first.quality, closeTo(0.32, 1e-9));
    expect(poor.sleeps.first.durationHours, closeTo(7, 1e-9));

    final well = parseJournal(entry('slept 23:10-6:45, slept well'));
    expect(well.sleeps.single.quality, closeTo(0.92, 1e-9));

    final plain = parseJournal(entry('slept 7h 30m'));
    expect(plain.sleeps.single.quality, isNull);
  });

  test('oatmeal and banana split into two estimates', () {
    final p = parseJournal(entry('ate oatmeal and banana'));
    expect(p.nutrition.map((e) => e.label), ['Oatmeal', 'Banana']);
    expect(p.nutrition.every((e) => !e.confirmed), isTrue);
  });

  test('imperial profile treats a bare weight as pounds', () {
    final p = parseJournal(entry('weighed 182'), units: 'imperial');
    expect(p.weights.single.kg, closeTo(182 / 2.2046226218, 1e-6));
  });

  test('5k, swim, gym minutes and comma-separated lifts parse', () {
    final five = parseJournal(entry('5k run'));
    expect(five.activities, hasLength(1));
    expect(five.activities.first.label, 'Run');
    expect(five.activities.first.minutes, closeTo(30, 1e-6));
    expect(five.activities.first.distanceKm, 5);

    final swim = parseJournal(entry('swam 30 min'));
    expect(swim.activities.single.label, 'Swim');
    expect(swim.activities.single.confirmed, isFalse);

    final gym = parseJournal(entry('gym 45 min'));
    expect(gym.activities.single.label, 'Gym');

    final trained = parseJournal(entry('trained 45 min'));
    expect(trained.activities.single.disciplineId, 'gym');
    expect(trained.activities.single.minutes, 45);

    final two = parseJournal(entry('bench 80x5, squat 100x5'));
    expect(two.sets, hasLength(2));
    expect(two.sets.map((s) => s.exerciseId), [
      'barbell-bench-press',
      'barbell-squat',
    ]);
  });

  test('a timed 5k stores pace, and other sports keep minutes', () {
    final timed = parseJournal(entry('ran 5k in 24:30'));
    expect(timed.activities, hasLength(1));
    expect(timed.activities.first.distanceKm, 5);
    expect(timed.activities.first.minutes, closeTo(24.5, 1e-9));
    expect(timed.activities.first.paceSecPerKm, closeTo(294, 1e-9));

    final football = parseJournal(entry('played football for 90 min'));
    expect(football.activities.single.disciplineId, 'football');
    expect(football.activities.single.minutes, 90);

    final yoga = parseJournal(entry('yoga 45 min'));
    expect(yoga.activities.single.disciplineId, 'yoga');
    expect(yoga.activities.single.minutes, 45);
  });

  test('drank coffee is a meal, not a session', () {
    final p = parseJournal(entry('drank coffee'));
    expect(p.nutrition.single.label, 'Coffee');
    expect(p.nutrition.single.confirmed, isTrue);
    expect(p.activities, isEmpty);
  });

  test('lunch and kebab are household estimates', () {
    expect(parseJournal(entry('had lunch')).nutrition.single.label, 'Lunch');
    expect(parseJournal(entry('ate kebab')).nutrition.single.kcal, 700);
    expect(parseJournal(entry('had hummus')).nutrition.single.label, 'Hummus');
  });

  test('handshake is not a protein shake', () {
    final p = parseJournal(entry('handshake after the session'));
    expect(p.nutrition, isEmpty);
    expect(p.isEmpty, isTrue);
  });

  test('effort, miles, races, steps, then-splits and other sports parse', () {
    final easy = parseJournal(entry('easy 8k'));
    expect(easy.activities.single.disciplineId, 'run');
    expect(easy.activities.single.distanceKm, 8);
    expect(easy.activities.single.effort, 'easy');

    final tempo = parseJournal(entry('tempo 6k'));
    expect(tempo.activities.single.effort, 'tempo');
    expect(tempo.activities.single.distanceKm, 6);

    final longRun = parseJournal(entry('long run 18k'));
    expect(longRun.activities.single.effort, 'long');
    expect(longRun.activities.single.distanceKm, 18);

    final miles = parseJournal(entry('ran 3 miles'));
    expect(miles.activities.single.distanceKm, closeTo(3 * 1.609344, 1e-6));

    final stroll = parseJournal(entry('went for a 45 min run'));
    expect(stroll.activities.single.disciplineId, 'run');
    expect(stroll.activities.single.minutes, 45);

    final race = parseJournal(entry('ran a marathon in 3:20'));
    expect(race.activities.single.distanceKm, closeTo(42.195, 1e-6));
    expect(race.activities.single.minutes, closeTo(200, 1e-9));
    expect(race.activities.single.effort, isNull);

    final half = parseJournal(entry('ran a half marathon'));
    expect(half.activities.single.distanceKm, closeTo(21.0975, 1e-6));

    final talk = parseJournal(entry('training for the marathon'));
    expect(talk.activities, isEmpty);

    final steps = parseJournal(entry('12000 steps'));
    expect(steps.activities.single.disciplineId, 'walk');
    expect(steps.activities.single.distanceKm, closeTo(9.6, 1e-9));

    final split = parseJournal(entry('ran 5k then ate oatmeal'));
    expect(split.activities.single.disciplineId, 'run');
    expect(split.activities.single.distanceKm, 5);
    expect(split.nutrition.single.label, 'Oatmeal');

    final rugby = parseJournal(entry('played rugby 80 min'));
    expect(rugby.activities.single.disciplineId, 'rugby');
    expect(rugby.activities.single.minutes, 80);

    final intervals = parseJournal(entry('intervals 8k'));
    expect(intervals.activities.single.disciplineId, 'run');
    expect(intervals.activities.single.effort, 'intervals');
    expect(intervals.activities.single.distanceKm, 8);

    final iRan = parseJournal(entry('I ran 5k'));
    expect(iRan.activities.single.disciplineId, 'run');
    expect(iRan.activities.single.distanceKm, 5);

    final justHad = parseJournal(entry("I've just had coffee"));
    expect(justHad.nutrition.single.label, 'Coffee');
    expect(justHad.nutrition.single.confirmed, isTrue);

    final water = parseJournal(entry('drank water'));
    expect(water.nutrition.single.label, 'Water');
    expect(water.nutrition.single.kcal, 0);
    expect(water.nutrition.single.confirmed, isTrue);

    final went = parseJournal(entry('went for a 5k'));
    expect(went.activities.single.disciplineId, 'run');
    expect(went.activities.single.distanceKm, 5);

    final morning = parseJournal(entry('this morning I ran 5k'));
    expect(morning.activities.single.disciplineId, 'run');
    expect(morning.activities.single.distanceKm, 5);

    final finished = parseJournal(entry('finished a 5k'));
    expect(finished.activities.single.distanceKm, 5);
  });

  test('counts scale a household estimate', () {
    final two = parseJournal(entry('ate 2 bananas'));
    expect(two.nutrition.single.label, 'Banana ×2');
    expect(two.nutrition.single.kcal, 210);

    final words = parseJournal(entry('ate two bananas'));
    expect(words.nutrition.single.kcal, 210);

    final eggs = parseJournal(entry('ate eggs'));
    expect(eggs.nutrition.single.label, 'Eggs');
    expect(eggs.nutrition.single.kcal, 180);

    final three = parseJournal(entry('ate 3 eggs'));
    expect(three.nutrition.single.label, 'Eggs ×3');
    expect(three.nutrition.single.kcal, 270);

    final one = parseJournal(entry('ate an egg'));
    expect(one.nutrition.single.label, 'Eggs ×1');
    expect(one.nutrition.single.kcal, 90);

    final coffees = parseJournal(entry('drank 3 coffees'));
    expect(coffees.nutrition.single.kcal, 15);
    expect(coffees.nutrition.single.confirmed, isTrue);

    final slices = parseJournal(entry('ate 4 slices of pizza'));
    expect(slices.nutrition.single.kcal, 1120);

    final bowl = parseJournal(entry('ate a bowl of oatmeal'));
    expect(bowl.nutrition.single.label, 'Oatmeal');
    expect(bowl.nutrition.single.kcal, 320);
  });

  test('went to bed and woke clock a night', () {
    final p = parseJournal(entry('went to bed at 23:10 woke at 6:45'));
    expect(p.sleeps, hasLength(1));
    expect(p.sleeps.single.durationHours, closeTo(7 + 35 / 60, 1e-6));

    final loose = parseJournal(entry('went to bed at 11 woke at 7'));
    expect(loose.sleeps.single.durationHours, closeTo(8, 1e-6));
  });

  test('a quality-only night does not invent hours', () {
    final p = parseJournal(entry('slept poorly'));
    expect(p.sleeps, isEmpty);
  });

  test('walk, ride and a named meal without a verb parse', () {
    final walk = parseJournal(entry('walked 30 min'));
    expect(walk.activities.single.disciplineId, 'walk');
    expect(walk.activities.single.minutes, 30);

    final ride = parseJournal(entry('cycled 20 km'));
    expect(ride.activities.single.disciplineId, 'cycle');
    expect(ride.activities.single.distanceKm, 20);

    final slot = parseJournal(entry('breakfast'));
    expect(slot.nutrition.single.label, 'Breakfast');

    final pizza = parseJournal(entry('had pizza for dinner'));
    expect(pizza.nutrition.single.label, 'Pizza (2 slices)');
  });

  test('Warsaw dictation hits household foods and sports', () {
    final oats = parseJournal(entry('zjadłem owsiankę'));
    expect(oats.nutrition.single.label, 'Oatmeal');

    final coffee = parseJournal(entry('wypiłem kawę'));
    expect(coffee.nutrition.single.label, 'Coffee');
    expect(coffee.nutrition.single.confirmed, isTrue);

    final meal = parseJournal(entry('śniadanie'));
    expect(meal.nutrition.single.label, 'Breakfast');

    final walk = parseJournal(entry('spacer 30 min'));
    expect(walk.activities.single.disciplineId, 'walk');
    expect(walk.activities.single.minutes, 30);

    final ride = parseJournal(entry('rower 20 km'));
    expect(ride.activities.single.disciplineId, 'cycle');
  });

  test('slept for hours, a weigh-in, and a bare mass parse', () {
    final hours = parseJournal(entry('slept for 7 hours'));
    expect(hours.sleeps.single.durationHours, closeTo(7, 1e-9));

    final weigh = parseJournal(entry('I weigh 82.4'));
    expect(weigh.weights.single.kg, 82.4);

    final bare = parseJournal(entry('82.4 kg'));
    expect(bare.weights.single.kg, 82.4);

    final pl = parseJournal(entry('spałem 7h'));
    expect(pl.sleeps.single.durationHours, closeTo(7, 1e-9));
  });

  test('sets x reps, bare session minutes, last night and household meals', () {
    final nxn = parseJournal(entry('3x5 bench 80'));
    expect(nxn.sets.single.exerciseName, 'Barbell bench press');
    expect(nxn.sets.single.weightKg, 80);
    expect(nxn.sets.single.reps, 5);
    expect(nxn.sets.single.sets, 3);

    final yoga = parseJournal(entry('yoga 45'));
    expect(yoga.activities.single.disciplineId, 'yoga');
    expect(yoga.activities.single.minutes, 45);

    final gym = parseJournal(entry('gym 45'));
    expect(gym.activities.single.disciplineId, 'gym');
    expect(gym.activities.single.minutes, 45);

    final mins = parseJournal(entry('slept 90 min'));
    expect(mins.sleeps.single.durationHours, closeTo(1.5, 1e-9));

    final night = parseJournal(entry('last night slept 7h'));
    expect(night.sleeps.single.durationHours, closeTo(7, 1e-9));

    expect(
      parseJournal(entry('ate schabowy')).nutrition.single.label,
      'Schabowy',
    );
    expect(parseJournal(entry('piwo')).nutrition.single.label, 'Beer');
    expect(parseJournal(entry('ate makaron')).nutrition.single.label, 'Pasta');
    expect(parseJournal(entry('ran 45')).activities, isEmpty);
    expect(
      parseJournal(entry('ate chicken salad')).nutrition.single.label,
      'Chicken salad',
    );
    expect(
      parseJournal(entry('ate tuna salad')).nutrition.single.label,
      'Tuna salad',
    );
    expect(parseJournal(entry('nalesniki')).nutrition.single.label, 'Pancakes');
    expect(
      parseJournal(
        entry('ate oatmeal with banana'),
      ).nutrition.map((e) => e.label),
      ['Oatmeal', 'Banana'],
    );
    expect(
      parseJournal(entry('ate chicken with rice')).nutrition.single.label,
      'Chicken and rice',
    );
    final kg = parseJournal(entry('3x5 bench 80kg'));
    expect(kg.sets.single.weightKg, 80);
    expect(kg.sets.single.sets, 3);

    final nap = parseJournal(entry('napped 20 min'));
    expect(nap.sleeps.single.durationHours, closeTo(20 / 60, 1e-9));
    expect(nap.sleeps.single.endHours, closeTo(18 + 20 / 60, 1e-9));
  });
}
