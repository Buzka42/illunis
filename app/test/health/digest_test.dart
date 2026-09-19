import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/health/digest.dart';

void main() {
  group('composeDayDigest', () {
    late AppStore store;
    const day = '2026-09-19';

    setUp(() {
      store = AppStore.memory();
    });

    test('synthesizes all 3 pillars: sleep, sets, deficit (concise default)', () {
      const s = DaySummary(
        day: day,
        sleepHours: 7.5,
        sleepScore: 0.85,
        sets: 18,
        intakeKcal: 2150,
        expenditureKcal: 2500,
        energyKcal: -350,
      );

      final digest = composeDayDigest(store, day, s);
      expect(digest, isNotNull);
      expect(digest, '7h 30m restful sleep, 18 sets lifted, and a 350 kcal deficit.');
      expect(digest!.length, lessThanOrEqualTo(140));
    });

    test('synthesizes all 3 pillars: narrative variant', () {
      const s = DaySummary(
        day: day,
        sleepHours: 7.5,
        sleepScore: 0.85,
        sets: 18,
        intakeKcal: 2150,
        expenditureKcal: 2500,
        energyKcal: -350,
      );

      final digest = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(digest, isNotNull);
      expect(
        digest,
        'A 350 kcal deficit accompanied 18 sets lifted following 7h 30m of restful sleep.',
      );
      expect(digest!.length, lessThanOrEqualTo(140));
    });

    test('synthesizes all 3 pillars: metric variant', () {
      const s = DaySummary(
        day: day,
        sleepHours: 7.5,
        sleepScore: 0.85,
        sets: 18,
        intakeKcal: 2150,
        expenditureKcal: 2500,
        energyKcal: -350,
      );

      final digest = composeDayDigest(store, day, s, variant: DigestVariant.metric);
      expect(digest, isNotNull);
      expect(
        digest,
        'Sleep 7h 30m (restful) · 18 sets · Energy −350 kcal (2150 in / 2500 out).',
      );
      expect(digest!.length, lessThanOrEqualTo(140));
    });

    test('synthesizes rest day with surplus and restful sleep', () {
      store.sleeps.add(
        const SleepEntry(
          id: 's1',
          journalEntryId: 'j1',
          day: day,
          startHours: -1.0,
          endHours: 7.25,
          quality: 0.9,
        ),
      );

      const s = DaySummary(
        day: day,
        sleepHours: 8.25,
        strain: 0,
        sets: 0,
        intakeKcal: 2700,
        expenditureKcal: 2500,
        energyKcal: 200,
      );

      final concise = composeDayDigest(store, day, s, variant: DigestVariant.concise);
      expect(concise, '8h 15m restful sleep across a rest day, closing at a 200 kcal surplus.');

      final narrative = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(
        narrative,
        'A rest day following 8h 15m of restful sleep closed with a 200 kcal surplus.',
      );

      final metric = composeDayDigest(store, day, s, variant: DigestVariant.metric);
      expect(
        metric,
        'Sleep 8h 15m (restful) · Rest day · Energy +200 kcal (2700 in / 2500 out).',
      );
    });

    test('synthesizes balanced energy within +/- 50 kcal', () {
      const s = DaySummary(
        day: day,
        sleepHours: 7.0,
        sets: 12,
        intakeKcal: 2420,
        expenditureKcal: 2400,
        energyKcal: 20,
      );

      final concise = composeDayDigest(store, day, s);
      expect(concise, '7h 00m sleep, 12 sets lifted, and balanced energy.');

      final narrative = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(
        narrative,
        'Balanced energy accompanied 12 sets lifted following 7h 00m of sleep.',
      );
    });

    test('synthesizes partial combinations: sleep + training only', () {
      const s = DaySummary(
        day: day,
        sleepHours: 6.75,
        sets: 15,
      );

      final concise = composeDayDigest(store, day, s);
      expect(concise, '6h 45m sleep paired with 15 sets lifted.');

      final narrative = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(narrative, 'Following 6h 45m of sleep, training logged 15 sets lifted.');

      final metric = composeDayDigest(store, day, s, variant: DigestVariant.metric);
      expect(metric, 'Sleep 6h 45m · 15 sets.');
    });

    test('synthesizes partial combinations: sleep + energy only', () {
      const s = DaySummary(
        day: day,
        sleepHours: 5.5,
        intakeKcal: 1800,
        expenditureKcal: 2200,
        energyKcal: -400,
      );

      final concise = composeDayDigest(store, day, s);
      expect(concise, '5h 30m short sleep and a 400 kcal deficit.');

      final narrative = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(
        narrative,
        'The day concluded with a 400 kcal deficit following 5h 30m of short sleep.',
      );
    });

    test('synthesizes partial combinations: training + energy only', () {
      const s = DaySummary(
        day: day,
        sets: 20,
        intakeKcal: 3100,
        expenditureKcal: 2600,
        energyKcal: 500,
      );

      final concise = composeDayDigest(store, day, s);
      expect(concise, '20 sets lifted with a 500 kcal surplus.');

      final narrative = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(narrative, '20 sets lifted concluded the day with a 500 kcal surplus.');
    });

    test('synthesizes single pillar records', () {
      // Sleep only
      const sleepOnly = DaySummary(day: day, sleepHours: 8.0);
      expect(
        composeDayDigest(store, day, sleepOnly, variant: DigestVariant.concise),
        '8h 00m restful sleep recorded.',
      );

      // Training only
      const trainOnly = DaySummary(day: day, sets: 14);
      expect(
        composeDayDigest(store, day, trainOnly, variant: DigestVariant.concise),
        '14 sets lifted logged.',
      );

      // Rest day only
      const restOnly = DaySummary(day: day, strain: 0, sets: 0);
      expect(
        composeDayDigest(store, day, restOnly, variant: DigestVariant.concise),
        'Rest.',
      );

      // Energy only
      const energyOnly = DaySummary(day: day, intakeKcal: 2000, expenditureKcal: 2300, energyKcal: -300);
      expect(
        composeDayDigest(store, day, energyOnly, variant: DigestVariant.concise),
        'A 300 kcal deficit recorded.',
      );
    });

    test('returns null when record has no figures', () {
      const empty = DaySummary(day: day);
      expect(composeDayDigest(store, day, empty), isNull);
    });

    test('synthesizes session activity and unrested sleep quality', () {
      store.sleeps.add(
        const SleepEntry(
          id: 's2',
          journalEntryId: 'j2',
          day: day,
          startHours: 1.0,
          endHours: 6.0,
          quality: 0.3,
        ),
      );

      store.activities.add(
        const ActivityEntry(
          id: 'a1',
          journalEntryId: 'j2',
          day: day,
          disciplineId: 'run',
          label: 'Run',
          distanceKm: 8.5,
          kcal: 550,
          confirmed: true,
        ),
      );

      const s = DaySummary(
        day: day,
        sleepHours: 5.0,
        distanceKm: 8.5,
        intakeKcal: 2200,
        expenditureKcal: 2600,
        energyKcal: -400,
      );

      final concise = composeDayDigest(store, day, s);
      expect(concise, contains('5h 00m sleep, poorly'));
      expect(concise, contains(RegExp('run', caseSensitive: false)));
      expect(concise, contains('400 kcal deficit'));

      final narrative = composeDayDigest(store, day, s, variant: DigestVariant.narrative);
      expect(narrative, contains('unrested sleep'));
      expect(narrative, contains(RegExp('run', caseSensitive: false)));
    });

    test('compliance with design laws across all combinations', () {
      final secondPerson = RegExp(r"\b(you|your|yours|you're|yourself)\b", caseSensitive: false);
      final advice = RegExp(
        r'\b(should|ought|try|need|aim|target|recommend|advise|prescribe|consider)\b',
        caseSensitive: false,
      );
      final causal = RegExp(
        r'\b(because|caused|causes|leads to|leading to|resulted in|resulting in|due to)\b',
        caseSensitive: false,
      );

      final testCases = <DaySummary>[
        const DaySummary(day: day, sleepHours: 7.8, sets: 22, energyKcal: 250, intakeKcal: 2800, expenditureKcal: 2550),
        const DaySummary(day: day, sleepHours: 5.2, strain: 0, sets: 0, energyKcal: -300, intakeKcal: 1900, expenditureKcal: 2200),
        const DaySummary(day: day, sleepHours: 6.0, sets: 8),
        const DaySummary(day: day, sleepHours: 9.0, energyKcal: 0, intakeKcal: 2400, expenditureKcal: 2400),
        const DaySummary(day: day, distanceKm: 12.0, moveMinutes: 65, energyKcal: -500),
        const DaySummary(day: day, strain: 0, sets: 0),
        const DaySummary(day: day, intakeKcal: 1500),
        const DaySummary(day: day, expenditureKcal: 2100),
      ];

      for (final s in testCases) {
        for (final variant in DigestVariant.values) {
          final digest = composeDayDigest(store, day, s, variant: variant);
          if (digest == null) continue;

          // 1. Length constraint
          expect(
            digest.length,
            lessThanOrEqualTo(140),
            reason: 'Variant $variant exceeded 140 chars: "$digest"',
          );

          // 2. No second person
          expect(
            secondPerson.hasMatch(digest),
            isFalse,
            reason: 'Variant $variant contained second person: "$digest"',
          );

          // 3. No advice
          expect(
            advice.hasMatch(digest),
            isFalse,
            reason: 'Variant $variant contained advice: "$digest"',
          );

          // 4. No medical/causal claims
          expect(
            causal.hasMatch(digest),
            isFalse,
            reason: 'Variant $variant contained causal claim: "$digest"',
          );

          // 5. Proper termination
          expect(
            digest.endsWith('.'),
            isTrue,
            reason: 'Variant $variant must end with a period: "$digest"',
          );
        }
      }
    });
  });
}
