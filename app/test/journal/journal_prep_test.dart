import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/core/sky/celestial_scene.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/civil_day.dart';
import 'package:illunis/core/theme/typography.dart';
import 'package:illunis/features/journal/journal_page.dart';

class JournalTestApp extends StatelessWidget {
  const JournalTestApp({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Illunis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07090D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEEF1F6),
          surface: Color(0xFF0B0E14),
        ),
        fontFamily: Type.text,
        textTheme: Type.theme,
        splashFactory: NoSplash.splashFactory,
      ),
      home: home,
    );
  }
}

List<Override> journalTestOverrides(AppStore store, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    storeProvider.overrideWith((ref) => store),
    civilDayProvider.overrideWithValue(today),
  ];
}

void main() {
  group('A1: Deterministic Fixtures', () {
    testWidgets('empty fixture: honest empty state and count', (tester) async {
      final store = JournalFixtures.empty();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      final model = container.read(journalPresentationModelProvider);
      expect(model.isEmpty, isTrue);
      expect(model.entryCount, 0);
      expect(find.text(S.journalEmpty), findsOneWidget);
      expect(find.text('0 ENTRIES'), findsOneWidget);
      expect(find.text(S.prev), findsOneWidget);
      expect(find.text(S.next), findsOneWidget);
      expect(model.canGoNext, isFalse);
    });

    testWidgets('dense day fixture: 25 entries read as one continuous list', (
      tester,
    ) async {
      final store = JournalFixtures.denseDay();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      final model = container.read(journalPresentationModelProvider);
      expect(model.entryCount, 25);
      expect(find.text('25 ENTRIES'), findsOneWidget);

      // One continuous list: no footer pager, newest first, all reachable.
      expect(find.text('NEWER'), findsNothing);
      expect(find.text('OLDER'), findsNothing);
      expect(find.textContaining('Entry item 24 -'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Entry item 0 -'));
      await tester.pump();
      expect(find.textContaining('Entry item 0 -'), findsOneWidget);
    });

    testWidgets('six short entries read as one day with no footer pager', (
      tester,
    ) async {
      final store = AppStore.memory();
      final now = DateTime.now();
      for (var i = 0; i < 6; i++) {
        store.journal.add(
          JournalEntry(
            id: 'short-$i',
            at: DateTime(now.year, now.month, now.day, 8 + i, 5),
            text: 'short note $i',
          ),
        );
      }
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);
      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      expect(find.text('NEWER'), findsNothing);
      expect(find.text('OLDER'), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(find.text('short note $i'), findsOneWidget);
      }
    });

    testWidgets('empty past days stay writable', (tester) async {
      final store = AppStore.memory();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);
      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      container.read(journalActionsProvider).prevDay();
      await tester.pump();
      final model = container.read(journalPresentationModelProvider);
      expect(model.isToday, isFalse);
      expect(model.isEmpty, isTrue);
      expect(find.text(S.journalEmptyDay), findsOneWidget);
      // The writer rides in the ground flow, even with nothing recorded.
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ground regions hold disjoint rects under load', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = JournalFixtures.yesterdayPendings();
      final now = DateTime.now();
      for (var i = 0; i < 4; i++) {
        store.journal.add(
          JournalEntry(
            id: 'g-$i',
            at: DateTime(now.year, now.month, now.day, 9 + i, 0),
            text: 'ground note $i with enough prose to take vertical room',
          ),
        );
      }
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);
      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      // Editing + error bands at once: the writer is at its tallest.
      container
          .read(journalSubmissionStateProvider.notifier)
          .setDraft(text: 'revise', keepLocal: false, replacesEntryId: 'g-0');
      container
          .read(journalSubmissionStateProvider.notifier)
          .onError('offline');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );
      await tester.pump();

      final selectedDay = container
          .read(journalPresentationModelProvider)
          .selectedDay;
      final record = tester.getRect(
        find.byKey(PageStorageKey('journal-record-$selectedDay')),
      );
      final dock = tester.getRect(find.byType(JournalPending));
      final writer = tester.getRect(find.byType(JournalWritingLine));
      expect(record.overlaps(dock), isFalse);
      expect(record.overlaps(writer), isFalse);
      expect(dock.overlaps(writer), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ground stays disjoint with the keyboard open', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2412);
      tester.view.devicePixelRatio = 3;
      tester.view.viewInsets = const FakeViewPadding(bottom: 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = JournalFixtures.yesterdayPendings();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);
      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: JournalPage(scene: scene),
            ),
          ),
        ),
      );
      await tester.pump();

      // Pending hides under the keyboard; record and writer stay disjoint.
      expect(find.byType(JournalPending), findsNothing);
      final record = tester.getRect(find.byType(SingleChildScrollView).first);
      final writer = tester.getRect(find.byType(JournalWritingLine));
      expect(record.overlaps(writer), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long prose fixture: compact multiline layout without error', (
      tester,
    ) async {
      final store = JournalFixtures.longProse();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      expect(find.textContaining('river trail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'mixed extractions fixture: lift, food, activity, sleep, weight',
      (tester) async {
        final store = JournalFixtures.mixedExtractions();
        final container = ProviderContainer(
          overrides: journalTestOverrides(store),
        );
        addTearDown(container.dispose);

        final model = container.read(journalPresentationModelProvider);
        expect(model.entryCount, 5);

        // Check extraction lines in presentation model
        final liftLines = model.extractionSummaries['entry-lift'];
        expect(liftLines, isNotNull);
        expect(liftLines!.first, contains('Bench Press'));
        expect(liftLines.first, contains('80 KG × 5 × 3'));

        final foodLines = model.extractionSummaries['entry-food'];
        expect(foodLines, isNotNull);
        expect(foodLines!.first, contains('Oatmeal  320 kcal'));

        final actLines = model.extractionSummaries['entry-act'];
        expect(actLines, isNotNull);
        expect(actLines!.first, contains('Run'));
        expect(actLines.first, contains('5.00 km'));

        final sleepLines = model.extractionSummaries['entry-sleep'];
        expect(sleepLines, isNotNull);
        expect(sleepLines!.first, contains('Sleep  7h 30m  well'));

        final weightLines = model.extractionSummaries['entry-weight'];
        expect(weightLines, isNotNull);
        expect(weightLines!.first, contains('82.4 KG'));
      },
    );

    testWidgets('yesterday pendings fixture: originating day prefix', (
      tester,
    ) async {
      final store = JournalFixtures.yesterdayPendings();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const JournalTestApp(home: Scaffold(body: JournalPending())),
        ),
      );

      final model = container.read(journalPresentationModelProvider);
      expect(model.pendingCount, 3);
      expect(find.textContaining('YESTERDAY  ·  pizza slice'), findsOneWidget);
      expect(find.textContaining('YESTERDAY  ·  evening walk'), findsOneWidget);
      expect(find.textContaining('protein shake'), findsOneWidget);
      expect(find.text('CONFIRM ALL'), findsOneWidget);
    });

    testWidgets('pending lane: fixed lane, ID-bound keys, stacked actions', (
      tester,
    ) async {
      final store = JournalFixtures.yesterdayPendings();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const JournalTestApp(home: Scaffold(body: JournalPending())),
        ),
      );

      // ID-bound CONFIRM / DROP keys for the first unconfirmed food row.
      final model = container.read(journalPresentationModelProvider);
      final firstId = model.unconfirmedFood.first.id;
      expect(
        find.byKey(ValueKey('pending-confirm-$firstId')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('pending-drop-$firstId')), findsOneWidget);

      // Every action target is at least 44dp.
      for (final key in [
        ValueKey('pending-confirm-$firstId'),
        ValueKey('pending-drop-$firstId'),
        const ValueKey('pending-confirm-all'),
      ]) {
        final box = tester.getSize(find.byKey(key));
        expect(box.width, greaterThanOrEqualTo(44));
        expect(box.height, greaterThanOrEqualTo(44));
      }

      // CONFIRM ALL is reachable inside the dock's internal scroll.
      await tester.ensureVisible(find.byKey(const ValueKey('pending-confirm-all')));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('pending-confirm-all'))),
        isNotNull,
      );
    });

    testWidgets('pending lane holds at 2x text scale without overflow', (
      tester,
    ) async {
      final store = JournalFixtures.yesterdayPendings();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: JournalTestApp(home: Scaffold(body: JournalPending())),
          ),
        ),
      );

      // Stacked: DROP sits above CONFIRM in the fixed 116dp lane.
      final model = container.read(journalPresentationModelProvider);
      final firstId = model.unconfirmedFood.first.id;
      final dropRect = tester.getRect(
        find.byKey(ValueKey('pending-drop-$firstId')),
      );
      final confirmRect = tester.getRect(
        find.byKey(ValueKey('pending-confirm-$firstId')),
      );
      expect(dropRect.bottom, lessThanOrEqualTo(confirmRect.top + 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('A1: Acceptance Criteria', () {
    testWidgets('unconfirmed estimates stay out of totals', (tester) async {
      final store = AppStore.memory();
      final today = dayKey(DateTime.now());

      // Add unconfirmed food
      store.nutrition.add(
        NutritionEntry(
          id: 'food-est',
          journalEntryId: 'j-1',
          day: today,
          label: 'salad',
          kcal: 250,
          confirmed: false,
        ),
      );
      // Add unconfirmed activity
      store.activities.add(
        ActivityEntry(
          id: 'act-est',
          journalEntryId: 'j-2',
          day: today,
          label: 'run',
          kcal: 400,
          minutes: 30,
          confirmed: false,
        ),
      );

      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const JournalTestApp(home: Scaffold(body: JournalPending())),
        ),
      );

      // Unconfirmed estimates must NOT appear in summary
      var summary = store.summaryOn(today);
      expect(summary?.intakeKcal ?? 0, 0);
      expect(summary?.moveMinutes ?? 0, 0);

      // Confirm food
      final actions = container.read(journalActionsProvider);
      await actions.confirmFood('food-est');
      await tester.pump();

      summary = store.summaryOn(today);
      expect(summary?.intakeKcal, 250);
      expect(summary?.moveMinutes ?? 0, 0); // Activity still unconfirmed

      // Confirm activity
      await actions.confirmActivity('act-est');
      await tester.pump();

      summary = store.summaryOn(today);
      expect(summary?.intakeKcal, 250);
      expect(summary?.moveMinutes, 30);
    });

    testWidgets('PREV/NEXT catch-up semantics', (tester) async {
      final store = AppStore.memory();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      final actions = container.read(journalActionsProvider);
      var model = container.read(journalPresentationModelProvider);

      expect(model.isToday, isTrue);
      expect(model.isCatchUp, isFalse);
      expect(model.canGoNext, isFalse);

      // Tap PREV -> navigates to yesterday in catch-up mode
      actions.prevDay();
      model = container.read(journalPresentationModelProvider);
      expect(model.isToday, isFalse);
      expect(model.isCatchUp, isTrue);
      expect(model.canGoNext, isTrue);

      // Submit unstamped line in catch-up mode -> logs on yesterday
      final entry = await actions.submit('stiff-leg deadlift 100x5x3');
      expect(entry, isNotNull);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(entry!.at.day, yesterday.day);

      // Tap NEXT -> returns to today, resetting catch-up
      actions.nextDay();
      model = container.read(journalPresentationModelProvider);
      expect(model.isToday, isTrue);
      expect(model.isCatchUp, isFalse);
      expect(model.canGoNext, isFalse);
    });

    testWidgets('KEEP LOCAL resets only after success', (tester) async {
      final store = AppStore.memory();
      final failingRepo = JournalFixtures.failedSubmitRepo(store);

      final container = ProviderContainer(
        overrides: [
          ...journalTestOverrides(store),
          journalRepositoryProvider.overrideWith((ref) => failingRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const JournalTestApp(
            home: Scaffold(body: JournalWritingLine()),
          ),
        ),
      );

      final actions = container.read(journalActionsProvider);
      // Toggle KEEP LOCAL on
      actions.setKeepLocal(true);
      await tester.pump();

      expect(find.text('LOCAL ONLY'), findsOneWidget);
      expect(container.read(journalSubmissionStateProvider).keepLocal, isTrue);

      // Submit that fails
      await tester.enterText(find.byType(TextField), 'private note');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // On failure, KEEP LOCAL must NOT reset!
      expect(find.text('LOCAL ONLY'), findsOneWidget);
      expect(container.read(journalSubmissionStateProvider).keepLocal, isTrue);
      expect(find.textContaining('NOT SAVED'), findsOneWidget);
      expect(find.text('private note'), findsOneWidget);

      // Now with working repo: submission succeeds
      final workingContainer = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(workingContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: workingContainer,
          child: const JournalTestApp(
            home: Scaffold(body: JournalWritingLine()),
          ),
        ),
      );

      final workingActions = workingContainer.read(journalActionsProvider);
      workingActions.setKeepLocal(true);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'private note 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // On success, KEEP LOCAL resets to false
      expect(find.text(S.keepLocal), findsOneWidget);
      expect(
        workingContainer.read(journalSubmissionStateProvider).keepLocal,
        isFalse,
      );
    });

    testWidgets('REVERT deletes entry+derived', (tester) async {
      final store = JournalFixtures.editRevert();
      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      expect(store.journal, hasLength(1));
      expect(store.nutrition, hasLength(1));

      final actions = container.read(journalActionsProvider);
      final reverted = await actions.revert('target-entry-1', putInDraft: true);
      expect(reverted, isNotNull);
      expect(reverted!.text, 'kawa 200ml i banan');

      // Both journal entry AND derived records must be deleted
      expect(store.journal, isEmpty);
      expect(store.nutrition, isEmpty);

      // Reverted text is offered in draft
      final subState = container.read(journalSubmissionStateProvider);
      expect(subState.draftText, contains('kawa 200ml i banan'));
      expect(subState.keepLocal, isTrue);
    });

    testWidgets("timeline hairlines stay today's pages even during catch-up", (
      tester,
    ) async {
      final store = AppStore.memory();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Entry today
      store.journal.add(
        JournalEntry(
          id: 'today-entry',
          at: DateTime(now.year, now.month, now.day, 9, 0),
          text: 'breakfast',
        ),
      );
      // Entry yesterday
      store.journal.add(
        JournalEntry(
          id: 'yest-entry',
          at: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 0),
          text: 'lunch yesterday',
        ),
      );

      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      // Marks for today
      final todayMarks = container.read(timelineMarksProvider);
      expect(todayMarks, isNotEmpty);

      // Navigate to yesterday in journal
      container.read(journalActionsProvider).prevDay();
      expect(container.read(journalDayProvider).day, yesterday.day);

      // Timeline marks must still represent TODAY's civil day!
      final marksAfterNav = container.read(timelineMarksProvider);
      expect(marksAfterNav, equals(todayMarks));
    });

    test('layout geometry separation and no-trap inputs', () {
      const inputs = JournalLayoutInputs(
        groundHeight: 400,
        keyboardInset: 240,
        pendingHeight: 148,
        textScale: 1.5,
      );

      expect(inputs.isKeyboardOpen, isTrue);
      // When keyboard is open, pending dock height does not squash writing line
      expect(inputs.effectiveDockHeight, 98.0);

      // Single ground budget: dock never overlaps the writer and never
      // squeezes the record below the minimum.
      expect(
        JournalLayoutInputs.pendingClamp(
          groundHeight: 400,
          writingHeight: 98.0,
          want: 148.0,
        ),
        148.0,
      );
      expect(
        JournalLayoutInputs.pendingClamp(
          groundHeight: 160,
          writingHeight: 98.0,
          want: 148.0,
        ),
        160 - 98.0 - 48.0,
      );

      // Clamping pending height: header + one stacked row band each.
      expect(JournalLayoutInputs.calculatePendingHeight(0), 0.0);
      expect(JournalLayoutInputs.calculatePendingHeight(1), 26.0 + 96.0);
      expect(JournalLayoutInputs.calculatePendingHeight(2), 148.0);
      expect(JournalLayoutInputs.calculatePendingHeight(20), 148.0);
    });

    testWidgets('preserve draft+focus across rebuilds', (tester) async {
      final container = ProviderContainer(
        overrides: journalTestOverrides(AppStore.memory()),
      );
      addTearDown(container.dispose);

      // Seed draft
      container
          .read(journalSubmissionStateProvider.notifier)
          .setDraft(
            text: 'persisted workout draft',
            keepLocal: true,
            replacesEntryId: 'edit-123',
            requestFocus: true,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const JournalTestApp(
            home: Scaffold(body: JournalWritingLine()),
          ),
        ),
      );

      expect(find.text('persisted workout draft'), findsOneWidget);
      expect(find.text('EDITING'), findsOneWidget);
      expect(find.text('LOCAL ONLY'), findsOneWidget);

      // Rebuild the widget
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const JournalTestApp(
            home: Scaffold(body: JournalWritingLine()),
          ),
        ),
      );

      expect(find.text('persisted workout draft'), findsOneWidget);
      expect(find.text('EDITING'), findsOneWidget);
      expect(find.text('LOCAL ONLY'), findsOneWidget);
    });

    testWidgets('dictation fallback focuses text field without crashing', (
      tester,
    ) async {
      final failingDictation = JournalFixtures.dictationFallback();
      final container = ProviderContainer(
        overrides: journalTestOverrides(AppStore.memory()),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(
              body: JournalWritingLine(dictation: failingDictation),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('journal-mic')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('long-press actions on entry tile and surface title survive', (
      tester,
    ) async {
      final store = AppStore.memory();
      final entry = JournalEntry(
        id: 'entry-to-revert',
        at: DateTime.now(),
        text: 'long press target',
      );
      store.journal.add(entry);

      final container = ProviderContainer(
        overrides: journalTestOverrides(store),
      );
      addTearDown(container.dispose);

      final scene = ValueNotifier<ResolvedScene?>(null);
      addTearDown(scene.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: JournalTestApp(
            home: Scaffold(body: JournalPage(scene: scene)),
          ),
        ),
      );

      // Long press on entry tile reverts entry
      expect(store.journal, hasLength(1));
      await tester.longPress(find.text('long press target'));
      await tester.pump();
      expect(store.journal, isEmpty);

      // Long press on SurfaceTitle opens Settings
      await tester.longPress(find.text(S.journal));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(S.settings), findsOneWidget);
      expect(find.text(S.deleteAll), findsOneWidget);
    });
  });
}
