import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/features/shell/illunis_shell.dart';
import 'package:illunis/main.dart';

void main() {
  testWidgets('first run guide is skippable and completion survives reload', (
    tester,
  ) async {
    final store = AppStore.memory();
    Widget app() => ProviderScope(
      overrides: illunisOverrides(store),
      child: const IllunisApp(home: IllunisShell(showTutorial: true)),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SKIP'), findsOneWidget);
    await tester.ensureVisible(find.text('SKIP'));
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.profile.tutorialVersion, 2);
    expect(Profile.fromJson(store.profile.toJson()).tutorialVersion, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SKIP'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
