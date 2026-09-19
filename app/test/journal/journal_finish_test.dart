import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/features/journal/journal_page.dart';
import 'package:illunis/main.dart';

Future<void> openJournal(
  WidgetTester tester,
  ProviderContainer container, {
  double scale = 1,
  bool reduced = false,
  double keyboard = 0,
}) async {
  await tester.runAsync(() async {
    for (final font in [
      ('Inter', 'Inter-Regular.ttf'),
      ('JetBrains Mono', 'JetBrainsMono-Variable.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 640),
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: const IllunisApp(),
      ),
    ),
  );
  await tester.pump();
  await tester.drag(find.byType(PageView).first, const Offset(600, 0));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'small journal, pending and editing with reduced motion $reduced',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = JournalFixtures.yesterdayPendings();
        final container = ProviderContainer(overrides: illunisOverrides(store));
        await openJournal(tester, container, reduced: reduced);
        expect(tester.takeException(), isNull);
        final field = find.byType(TextField);
        expect(
          tester.getSize(find.byKey(const ValueKey('journal-mic'))),
          const Size(44, 44),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('journal-save'))).height,
          greaterThanOrEqualTo(44),
        );
        final confirm = find.text('CONFIRM').first;
        await tester.ensureVisible(confirm);
        await tester.pump();
        expect(confirm.hitTestable(), findsOneWidget);
        await tester.tap(confirm);
        await tester.pump(const Duration(milliseconds: 220));
        expect(store.nutrition.first.confirmed, isTrue);
        expect(tester.takeException(), isNull);
        await tester.enterText(field, 'A line to keep');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('journal-save')));
        await tester.pump(const Duration(milliseconds: 220));
        expect(store.journal.single.text, 'A line to keep');
        container.read(journalActionsProvider).edit(store.journal.single);
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.text('EDITING'), findsOneWidget);
        expect(
          tester.widget<TextField>(field).controller!.text,
          contains('A line to keep'),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        store.dispose();
      },
    );

    testWidgets(
      'keyboard keeps the draft reachable at 2x, reduced motion $reduced',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = AppStore.memory();
        final container = ProviderContainer(overrides: illunisOverrides(store));
        await openJournal(
          tester,
          container,
          scale: 2,
          reduced: reduced,
          keyboard: 260,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomLeft(find.byType(JournalWritingLine)).dy,
          lessThanOrEqualTo(380),
        );
        await tester.enterText(find.byType(TextField), 'Still here.');
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Still here.',
        );
        expect(
          find.byKey(const ValueKey('journal-save')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        store.dispose();
      },
    );
  }

  testWidgets('failed save above keyboard retains draft and local choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    final container = ProviderContainer(
      overrides: [
        ...illunisOverrides(store),
        journalRepositoryProvider.overrideWith(
          (ref) => JournalFixtures.failedSubmitRepo(store),
        ),
      ],
    );
    await openJournal(
      tester,
      container,
      scale: 2,
      reduced: true,
      keyboard: 260,
    );
    container.read(journalActionsProvider).setKeepLocal(true);
    await tester.enterText(find.byType(TextField), 'Private draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('journal-save')));
    await tester.pump();
    expect(find.textContaining('NOT SAVED'), findsOneWidget);
    expect(container.read(journalSubmissionStateProvider).keepLocal, isTrue);
    expect(
      container.read(journalSubmissionStateProvider).draftText,
      'Private draft',
    );
    expect(
      tester.getBottomLeft(find.byType(JournalWritingLine)).dy,
      lessThanOrEqualTo(380),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    store.dispose();
  });

  testWidgets('prose is not truncated; confirmed extractions are subordinate', (
    tester,
  ) async {
    final store = JournalFixtures.mixedExtractions();
    final container = ProviderContainer(overrides: illunisOverrides(store));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: IllunisApp(
          home: Scaffold(body: JournalEntryTile(entry: store.journal[1])),
        ),
      ),
    );
    final prose = tester.widget<Text>(find.text('ate oatmeal'));
    final extract = tester.widget<Text>(
      find.textContaining('Oatmeal  320 kcal'),
    );
    expect(prose.maxLines, isNull);
    expect(extract.style!.fontSize, lessThan(prose.style!.fontSize!));
    expect(
      tester.getTopLeft(find.textContaining('Oatmeal  320 kcal')).dy,
      greaterThan(tester.getTopLeft(find.text('ate oatmeal')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    store.dispose();
  });
}
