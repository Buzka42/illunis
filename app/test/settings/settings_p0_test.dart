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
}
