import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/sky/sky_state.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/features/timeline/calorie_marks.dart';
import 'package:illunis/features/timeline/timeline_bar.dart';

void main() {
  final at = DateTime(2026, 9, 11, 12, 30);
  final day = dayKey(at);
  AppStore fixture() =>
      AppStore.memory()
        ..journal.add(JournalEntry(id: 'page', at: at, text: 'lunch and walk'));
  NutritionEntry meal(
    String id,
    double kcal, {
    bool confirmed = true,
    String parent = 'page',
    String? recordDay,
  }) => NutritionEntry(
    id: id,
    journalEntryId: parent,
    day: recordDay ?? day,
    label: 'meal',
    kcal: kcal,
    confirmed: confirmed,
  );

  test('aggregates confirmed meals per page and keeps burn separate', () {
    final store = fixture()
      ..nutrition.addAll([meal('a', 200), meal('b', 300)])
      ..activities.add(
        ActivityEntry(
          id: 'walk',
          journalEntryId: 'page',
          day: day,
          label: 'walk',
          kcal: 150,
          confirmed: true,
        ),
      );
    final marks = calorieMarksOn(store, day);
    expect(marks.map((m) => m.kcal), [500, 150]);
    expect(marks.map((m) => m.kind), [CalorieKind.intake, CalorieKind.burn]);
    expect(marks.first.time, 12.5 / 24);
    expect(calorieMarksOn(store, '2026-09-12'), isEmpty);
    store.dispose();
  });

  test('unknown, pending, orphaned and invalid records never become dots', () {
    final store = fixture()
      ..nutrition.addAll([
        meal('pending', 500, confirmed: false),
        meal('zero', 0),
        meal('negative', -50),
        meal('nan', double.nan),
        meal('infinite', double.infinity),
        meal('orphan', 100, parent: 'gone'),
        meal('other-day', 100, recordDay: '2026-09-10'),
      ]);
    expect(calorieMarksOn(store, day), isEmpty);
    store.nutrition.add(meal('valid', 100));
    expect(calorieMarksOn(store, day), hasLength(1));
    store.journal.clear();
    expect(calorieMarksOn(store, day), isEmpty);
    store.dispose();
  });

  test('dot weight is monotonic and bounded for large confirmed meals', () {
    const small = CalorieMark(0.5, 50, CalorieKind.intake);
    const large = CalorieMark(0.5, 800, CalorieKind.intake);
    const huge = CalorieMark(0.5, 10000, CalorieKind.intake);
    expect(small.radius, lessThan(large.radius));
    expect(small.alpha, lessThan(large.alpha));
    expect(huge.radius, 3);
    expect(huge.alpha, 0.9);
  });

  testWidgets('Blade timeline keeps 48 dp height and exposes dot meaning', (
    tester,
  ) async {
    final store = fixture();
    final scene = ValueNotifier<ResolvedScene?>(
      CelestialScene.resolve(
        const SkyState(
          timeOfDay: 0.5,
          dayOfYear: 254,
          epochDays: 9749.5,
          latitudeDeg: 52.23,
          moonPhase: 0.25,
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          calorieMarksProvider.overrideWith(
            (ref, day) => const [
              CalorieMark(0, 100, CalorieKind.intake),
              CalorieMark(0.5, 500, CalorieKind.burn),
              CalorieMark(0.999, 10000, CalorieKind.intake),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 360, child: TimelineBar(scene: scene)),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TimelineBar)), const Size(360, 48));
    expect(
      find.bySemanticsLabel(
        RegExp('Confirmed calories at journal logging times'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
    scene.dispose();
    store.dispose();
  });
}
