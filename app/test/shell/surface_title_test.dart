import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/main.dart';

/// The titles live inside the swipe pager. A real finger drifts; the
/// pager's drag recognizer then wins the gesture arena and a stock
/// `onLongPress` never fires (pre-V2 the target sat on the bottom bar,
/// outside the pager). These tests hold with drift, the way hardware does.
void main() {
  testWidgets('long-press with finger drift opens Settings', (tester) async {
    final store = AppStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('DASHBOARD'), findsOneWidget);

    final center = tester.getCenter(find.text('DASHBOARD'));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(25, 3));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('SETTINGS'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('swipe navigation still pages after the fix', (tester) async {
    final store = AppStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('DASHBOARD'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    Offset? prev;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      final c = tester.getCenter(find.text('JOURNAL'));
      if (prev != null && (c - prev).distance < 1 && c.dx > 0) break;
      prev = c;
    }
    expect(find.text('JOURNAL'), findsOneWidget);
    // And the journal title keeps the same drift-tolerant hold.
    final center = tester.getCenter(find.text('JOURNAL'));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(-22, 4));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
