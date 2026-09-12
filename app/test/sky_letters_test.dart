import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/patterns/statistics.dart';
import 'package:illunis/core/patterns/sweep.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/civil_day.dart';
import 'package:illunis/features/insights/sky_letters.dart';

void main() {
  test(
    'day-one digest stays separate from correlations with fewer than 21 pairs',
    () {
      final container = ProviderContainer(
        overrides: [
          todayFiguresProvider.overrideWithValue(
            const TodayFigures(
              day: '2026-09-12',
              summary: DaySummary(
                day: '2026-09-12',
                digest: 'Intake 320 kcal.',
                digestSource: 'local',
              ),
              findings: [
                PatternFinding(
                  id: 'not-ready',
                  pairLabel: 'sleep',
                  sentence: 'Hidden.',
                  correlation: Correlation(r: 0.8, n: 20, p: 0.001),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final letters = container.read(skyLettersProvider);
      expect(letters, hasLength(1));
      expect(letters.single.provenance, 'DAILY · RULE');
    },
  );

  testWidgets(
    'two taps dismiss, persistence survives restart, civil rollover resets',
    (tester) async {
      var day = DateTime(2026, 10, 25);
      final store = AppStore.memory();
      ProviderContainer create() => ProviderContainer(
        overrides: [
          storeProvider.overrideWithValue(store),
          civilDayProvider.overrideWith((ref) => day),
          skyLettersProvider.overrideWithValue(const [
            SkyLetter('digest', 'A daily sentence.', 'DAILY · RULE'),
          ]),
        ],
      );
      var container = create();
      Future<void> mount() => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SkyLetters(ink: Colors.white)),
          ),
        ),
      );
      await mount();
      await tester.tap(find.text('A daily sentence.'));
      await tester.pump();
      expect(find.text('tap again to dismiss'), findsOneWidget);
      expect(store.profile.dismissedInsightIds, isEmpty);
      await tester.tap(find.text('A daily sentence.'));
      await tester.pump();
      expect(find.text('A daily sentence.'), findsNothing);
      store.profile = Profile.fromJson(store.profile.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      container = create();
      await mount();
      expect(find.text('A daily sentence.'), findsNothing);
      day = DateTime(2026, 10, 26); // calendar day after autumn DST change
      container.invalidate(civilDayProvider);
      await tester.pump();
      expect(find.text('A daily sentence.'), findsOneWidget);
      expect(find.text('tap again to dismiss'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      store.dispose();
    },
  );

  test('civil day changes preserve catch-up selection', () async {
    var day = DateTime(2026, 3, 29);
    final container = ProviderContainer(
      overrides: [civilDayProvider.overrideWith((ref) => day)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(journalDayProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(container.read(journalDayProvider), day);
    day = DateTime(2026, 3, 30);
    container.invalidate(civilDayProvider);
    await container.pump();
    expect(container.read(journalDayProvider), day);
    container.read(journalDayProvider.notifier).prev();
    expect(container.read(journalDayProvider), DateTime(2026, 3, 29));
    day = DateTime(2026, 3, 31);
    container.invalidate(civilDayProvider);
    await container.pump();
    expect(container.read(journalDayProvider), DateTime(2026, 3, 29));
  });
}
