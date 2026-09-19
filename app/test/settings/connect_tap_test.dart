import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/wearables/health_bridge.dart';
import 'package:illunis/core/wearables/wearable_data.dart';
import 'package:illunis/features/settings/settings_sheet.dart';

class FakeBridge implements HealthBridge {
  int dailyCalls = 0;
  int permissionCalls = 0;
  WearableDailyData? dataToReturn;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> requestPermissions() async {
    permissionCalls++;
    return true;
  }

  @override
  Future<WearableDailyData?> getDailyData(DateTime date) async {
    dailyCalls++;
    return dataToReturn;
  }
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  expect(find.text('CONNECT / REFRESH WEARABLE'), findsOneWidget);
}

Widget host() => const MaterialApp(
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

Future<void> tapConnect(WidgetTester tester) async {
  final line = find.text('CONNECT / REFRESH WEARABLE');
  await tester.scrollUntilVisible(line, 300);
  await tester.pumpAndSettle();
  await tester.tap(line);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('CONNECT tap reaches bridge and reports refresh (data path)',
      (tester) async {
    final bridge = FakeBridge()
      ..dataToReturn = const WearableDailyData(steps: 1234);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...illunisOverrides(AppStore.memory()),
          healthBridgeProvider.overrideWith((ref) => bridge),
        ],
        child: host(),
      ),
    );
    await openSheet(tester);
    await tapConnect(tester);
    expect(bridge.dailyCalls, greaterThanOrEqualTo(1));
    expect(
      find.text('Wearable refreshed from Health Connect.'),
      findsOneWidget,
    );
  });

  testWidgets('CONNECT tap with empty read falls through to permissions',
      (tester) async {
    final bridge = FakeBridge()..dataToReturn = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...illunisOverrides(AppStore.memory()),
          healthBridgeProvider.overrideWith((ref) => bridge),
        ],
        child: host(),
      ),
    );
    await openSheet(tester);
    await tapConnect(tester);
    expect(bridge.dailyCalls, greaterThanOrEqualTo(1));
    expect(bridge.permissionCalls, equals(1));
    expect(find.text('Wearable refresh requested.'), findsOneWidget);
  });
}
