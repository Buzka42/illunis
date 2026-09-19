import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/main.dart';

void main() {
  testWidgets('writing line SAVE is gated on trimmed text', (tester) async {
    final store = AppStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.drag(find.byType(PageView).first, const Offset(600, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final save = find.text('SAVE');
    expect(save, findsOneWidget);

    // Empty: tap saves nothing.
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.journal, isEmpty);

    // Whitespace-only: tap saves nothing.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.journal, isEmpty);

    // Real text: tap saves one entry.
    await tester.enterText(find.byType(TextField), 'just a line');
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.journal, hasLength(1));
    expect(store.journal.first.text, 'just a line');
  });
}
