import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/theme/typography.dart';
import 'package:illunis/features/shell/illunis_shell.dart';
import 'package:illunis/main.dart';

void main() {
  testWidgets('the shell builds with both surfaces and the sky', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: IllunisApp()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(IllunisShell), findsOneWidget);
    expect(find.text('ILLUNIS'), findsOneWidget);
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('JOURNAL'), findsWidgets);
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
