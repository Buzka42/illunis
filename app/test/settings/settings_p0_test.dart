import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/features/settings/settings_sheet.dart';

Widget _host() => const MaterialApp(
  home: Scaffold(
    body: Center(
      child: _Opener(),
    ),
  ),
);

class _Opener extends StatelessWidget {
  const _Opener();
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showSettingsSheet(context),
      child: const Text('OPEN'),
    );
  }
}

void main() {
  testWidgets(
    'settings P0: consent readable, DELETE reachable at 1080x2412/72+144',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2412);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 72, bottom: 144);
      tester.view.viewPadding = const FakeViewPadding(bottom: 144);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final store = AppStore.memory();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: illunisOverrides(store),
          child: _host(),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      // Section grouping present.
      for (final s in ['DATA', 'SOURCES', 'PRIVACY']) {
        expect(find.text(s), findsOneWidget);
      }

      // Consent fully readable.
      final consent = find.textContaining(S.aiConsent);
      await tester.scrollUntilVisible(consent, 400);
      await tester.pumpAndSettle();
      expect(consent, findsOneWidget);
      expect(tester.getTopLeft(consent).dy, greaterThanOrEqualTo(0));
      expect(
        tester.getBottomRight(consent).dy,
        lessThanOrEqualTo(2412),
      );

      // DELETE ALL DATA reachable in its own bottom zone.
      final del = find.text(S.deleteAll);
      await tester.scrollUntilVisible(del, 400);
      await tester.pumpAndSettle();
      expect(del, findsOneWidget);

      // At the bottom there is nothing below the fold: no MORE cue.
      expect(find.text('MORE ↓'), findsNothing);

      // Confirm-tap pattern: first tap arms, second tap deletes.
      await tester.tap(del);
      await tester.pumpAndSettle();
      expect(find.text(S.confirmDelete), findsOneWidget);
    },
  );

  testWidgets('settings: enlarged text keeps consent readable', (tester) async {
    final store = AppStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
            size: Size(360, 640),
          ),
          child: _host(),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    final consent = find.textContaining(S.aiConsent);
    await tester.scrollUntilVisible(consent, 400);
    await tester.pumpAndSettle();
    expect(consent, findsOneWidget);
    // Readable: fully inside the viewport, no clipping.
    final rect = tester.getRect(consent);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(640));
  });

  testWidgets('settings: MORE cue shows only while content continues', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(overrides: illunisOverrides(store), child: _host()),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    // Full-height sheet: nothing below the fold, no cue.
    expect(find.text('MORE ↓'), findsNothing);
  });

  test('settings: import rejects invalid payload, store untouched', () async {
    // Import behavior unchanged: a bad payload throws and leaves the store
    // exactly as it was. (Clipboard delivery is platform-owned; the sheet
    // maps any failure to S.importFailed without touching the store.)
    final store = AppStore.memory();
    addTearDown(store.dispose);
    await expectLater(
      store.importJson('not json'),
      throwsA(isA<FormatException>()),
    );
    expect(store.summaries, isEmpty);
  });
}
