import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/i18n/dates.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/features/dashboard/dashboard_page.dart';
import 'package:illunis/main.dart';

void main() {
  testWidgets('dashboard is honest when the record is empty', (tester) async {
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(S.noData), findsOneWidget);
    expect(find.text(S.emptyDash), findsWidgets);
    expect(find.text(S.mockData), findsNothing);
    expect(find.text(S.mass), findsNothing);
    expect(find.text(S.recovery), findsNothing);
    expect(find.text(S.intake), findsNothing);
    expect(find.text(S.training), findsNothing);
    expect(find.text(S.energy), findsNothing);
  });

  testWidgets('journal writing line stores a lift', (tester) async {
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'bench 80x5x3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.journal, hasLength(1));
    expect(store.sets, hasLength(1));
    expect(find.text('bench 80x5x3'), findsOneWidget);
    expect(find.text('1 ENTRY'), findsOneWidget);
    expect(find.text(S.prev), findsWidgets);
  });

  testWidgets('mic tap without a recognizer still leaves the field', (
    tester,
  ) async {
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('journal-mic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard prev looks at yesterday', (tester) async {
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardPage),
        matching: find.text(S.prev),
      ),
    );
    await tester.pump();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(
      find.text(
        formatShortDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a 1080×2412 phone does not overflow the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('% · '), findsOneWidget);
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ran 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.journal, hasLength(1));
    expect(tester.takeException(), isNull);
    expect(find.text(S.confirm), findsOneWidget);
  });

  testWidgets('drop keeps the page and revert takes it back', (tester) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'ran 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(S.drop), findsOneWidget);
    expect(find.textContaining('kcal'), findsOneWidget);
    await tester.tap(find.text(S.drop));
    await tester.pump();
    expect(store.activities, isEmpty);
    expect(store.journal, hasLength(1));
    expect(find.text(S.confirm), findsNothing);
    await tester.tap(find.text(S.revert));
    await tester.pump();
    expect(store.journal, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      contains('ran 5k'),
    );
  });

  testWidgets('the IME lifts the writing line instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 360);
    tester.view.padding = const FakeViewPadding(bottom: 144, top: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(AppStore.memory()),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a leading clock is the page time, not the prose', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), '7:30 ran 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.journal.single.text, 'ran 5k');
    expect(store.journal.single.at.hour, 7);
    expect(store.journal.single.at.minute, 30);
    expect(find.text('ran 5k'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text(S.keepLocal), findsOneWidget);
  });

  testWidgets('confirming a meal writes INTAKE on the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'ate oatmeal');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(S.confirm));
    await tester.pump();
    expect(store.nutrition.single.confirmed, isTrue);
    await tester.tap(find.text(S.dashboard).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('320'), findsOneWidget);
    expect(find.textContaining('P 12'), findsOneWidget);
    expect(find.textContaining('INTAKE 320'), findsOneWidget);
    expect(find.textContaining('Intake 320 kcal'), findsOneWidget);
  });

  testWidgets('sleep and mass reach the dashboard without a confirm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'slept 7h poorly');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'weighed 82.4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(S.dashboard).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('7h 00m'), findsOneWidget);
    expect(find.textContaining('POORLY'), findsOneWidget);
    expect(find.textContaining('Sleep 7h 00m, poorly'), findsOneWidget);
    expect(find.text('82.4'), findsOneWidget);
  });

  testWidgets('an unconfirmed run is not a dashboard session', (tester) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'ran 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(S.dashboard).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('RUN'), findsNothing);
    expect(find.text(S.training), findsNothing);
    expect(find.text(S.local), findsOneWidget);
    expect(find.text(S.noData), findsNothing);
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(S.confirm));
    await tester.pump();
    await tester.tap(find.text(S.dashboard).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('RUN'), findsOneWidget);
  });

  testWidgets('coffee is intake without a confirm', (tester) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'drank coffee');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(S.confirm), findsNothing);
    expect(store.nutrition.single.confirmed, isTrue);
    await tester.tap(find.text(S.dashboard).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('yesterday from today opens that civil day', (tester) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'yesterday ran 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final day = DateTime(yesterday.year, yesterday.month, yesterday.day);
    expect(store.journal.single.text, 'ran 5k');
    expect(store.journal.single.at.year, day.year);
    expect(store.journal.single.at.month, day.month);
    expect(store.journal.single.at.day, day.day);
    expect(find.text(formatLongDate(day)), findsOneWidget);
    expect(find.text('ran 5k'), findsOneWidget);
  });

  testWidgets('yesterday is the calendar day even from a catch-up page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(S.journal).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(S.prev).last);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'yesterday ran 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(store.journal.single.at.year, yesterday.year);
    expect(store.journal.single.at.month, yesterday.month);
    expect(store.journal.single.at.day, yesterday.day);
  });
}
