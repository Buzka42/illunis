import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/core/journal/marks.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/features/journal/journal_page.dart';
import 'package:illunis/main.dart';

void main() {
  group('Launch Blocker 1: Pending dock clamp', () {
    test('heightFor clamps at maxPendingHeight for high item counts', () {
      // Geometry: 1×88, +44 confirm-all past 1 item, clamp 148 (Astra rhythm).
      expect(JournalPending.heightFor(0), 0.0);
      expect(JournalPending.heightFor(1), 88.0);
      expect(JournalPending.heightFor(2), 148.0);
      expect(JournalPending.heightFor(3), 148.0);
      expect(JournalPending.heightFor(10), 148.0);
      expect(JournalPending.heightFor(25), 148.0);
    });

    testWidgets('JournalPending renders scrollable when count exceeds clamp', (
      tester,
    ) async {
      final today = dayKey(DateTime.now());
      final foods = List.generate(
        8,
        (i) => NutritionEntry(
          id: 'food-$i',
          journalEntryId: 'j-$i',
          day: today,
          label: 'Food item $i',
          confirmed: false,
          kcal: 100,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          storeProvider.overrideWith((ref) => AppStore.memory()),
          journalFiguresProvider.overrideWithValue(
            TodayFigures(
              day: today,
              entryCount: 8,
              unconfirmed: foods,
              summary: DaySummary(day: today),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IllunisApp(home: Scaffold(body: JournalPending())),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('CONFIRM ALL'), findsOneWidget);
    });
  });

  group('Launch Blocker 2: Entry edit vs duplicate semantics', () {
    testWidgets('Tapping an entry offers draft with replacesEntryId', (
      tester,
    ) async {
      final store = AppStore.memory();
      final now = DateTime.now();
      final entry = JournalEntry(
        id: 'entry-original',
        at: now,
        text: 'kawa 200ml',
      );
      store.journal.add(entry);

      final container = ProviderContainer(
        overrides: [storeProvider.overrideWith((ref) => store)],
      );

      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: IllunisApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      // Tap on the existing entry
      await tester.tap(find.text('kawa 200ml'));
      await tester.pump();

      final draft = container.read(journalDraftProvider);
      expect(draft, isNotNull);
      expect(draft!.replacesEntryId, 'entry-original');
      final h = now.hour.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      expect(draft.text, '$h:$m kawa 200ml');
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    testWidgets('Writing line displays EDITING when replacing entry', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IllunisApp(home: Scaffold(body: JournalWritingLine())),
        ),
      );

      container
          .read(journalDraftProvider.notifier)
          .offer(
            const JournalDraft('14:30 herbata', replacesEntryId: 'old-id'),
          );
      await tester.pump();

      expect(find.text('EDITING'), findsOneWidget);
      expect(find.text(S.drop), findsOneWidget);

      // Tapping DROP clears the edit
      await tester.tap(find.text(S.drop));
      await tester.pump();

      expect(find.text('EDITING'), findsNothing);
    });
  });

  group('Launch Blocker 3: Stale multi-day sleep exclusion', () {
    test('Today figures do not inherit sleep from 3 days ago', () async {
      final store = AppStore.memory();
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      // Put an old completed sleep
      store.sleeps.add(
        SleepEntry(
          id: 'sleep-old',
          journalEntryId: 'j-old',
          day: dayKey(threeDaysAgo),
          startHours: 23.0,
          endHours: 31.0,
          quality: 0.8,
        ),
      );

      final container = ProviderContainer(
        overrides: [storeProvider.overrideWith((ref) => store)],
      );
      addTearDown(container.dispose);

      final figures = container.read(journalFiguresProvider);
      // Today figures must NOT leak 3-day-old sleep
      expect(figures.sleep, isNull);
    });

    test('Today figures accept sleep completed yesterday night', () async {
      final store = AppStore.memory();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      store.sleeps.add(
        SleepEntry(
          id: 'sleep-yesterday',
          journalEntryId: 'j-yesterday',
          day: dayKey(yesterday),
          startHours: 23.0,
          endHours: 31.0,
          quality: 0.85,
        ),
      );

      final container = ProviderContainer(
        overrides: [storeProvider.overrideWith((ref) => store)],
      );
      addTearDown(container.dispose);

      final figures = container.read(journalFiguresProvider);
      expect(figures.sleep, isNotNull);
      expect(figures.sleep!.id, 'sleep-yesterday');
    });
  });

  group('Launch Polish: Civil wall-clock timeline marks', () {
    test('timeOfDayFraction strictly represents wall-clock position', () {
      final midnight = DateTime(2026, 3, 29, 0, 0, 0); // European DST day
      final noon = DateTime(2026, 3, 29, 12, 0, 0);
      final evening = DateTime(2026, 3, 29, 18, 0, 0);

      expect(timeOfDayFraction(midnight), closeTo(0.0, 0.0001));
      expect(timeOfDayFraction(noon), closeTo(0.5, 0.0001));
      expect(timeOfDayFraction(evening), closeTo(0.75, 0.0001));
    });
  });

  group('Launch Blocker 4: AI Consent disclosure', () {
    test('aiConsent discloses cloud processing', () {
      expect(S.aiConsent, contains('CLOUD'));
      expect(S.aiConsentNote, contains('off-device'));
    });
  });

  group('Launch Polish: Accessibility Semantics pass', () {
    testWidgets('Journal controls provide accessibility semantics', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IllunisApp(home: Scaffold(body: JournalWritingLine())),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label == 'Start dictation',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label == 'Keep local disabled',
        ),
        findsOneWidget,
      );
    });
  });
}
