import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/theme/typography.dart';
import 'package:illunis/features/shell/dream_shell.dart';
import 'package:illunis/features/shell/illunis_shell.dart';
import 'package:illunis/main.dart';

void main() {
  testWidgets('the shell builds with both surfaces and the sky', (
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
    expect(find.byType(IllunisShell), findsOneWidget);
    expect(find.text('ILLUNIS'), findsOneWidget);
    expect(find.text(S.dashboard), findsOneWidget);
    expect(find.text(S.journal), findsNothing);
    expect(find.text(S.version), findsNothing);
  });

  testWidgets('a zero-width first frame does not throw', (tester) async {
    tester.view.physicalSize = const Size(1, 1);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(AppStore.memory()),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the nightstand builds without the pager', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(AppStore.memory()),
        child: const IllunisApp(home: DreamShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(DreamShell), findsOneWidget);
    expect(find.text('NIGHTSTAND'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsNothing);
  });

  test('every TextTheme slot is defined by the product type', () {
    final t = Type.theme;
    for (final style in [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
    ]) {
      expect(style, isNotNull);
      expect(style!.fontFamily, anyOf(Type.text, Type.mono));
    }
  });
}
