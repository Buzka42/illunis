import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/journal/repository.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/civil_day.dart';
import 'package:illunis/core/state/sleep_record.dart';
import 'package:illunis/core/wearables/wearable_data.dart';
import 'package:illunis/main.dart';

DateTime _morning(DateTime now) =>
    DateTime(now.year, now.month, now.day, 7, 5);

void main() {
  test('a logged night reaches the timeline provider', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    await JournalRepository(
      store,
    ).log('slept 23:10 to 06:45', at: _morning(now));
    final container = ProviderContainer(overrides: illunisOverrides(store));
    addTearDown(container.dispose);
    addTearDown(store.dispose);
    final sleep = container.read(sleepRecordProvider);
    expect(sleep, isNotNull);
    expect(sleep!.durationHours, closeTo(7 + 35 / 60, 1e-6));
  });

  test('a later nap does not shadow the night on the timeline', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    final repo = JournalRepository(store);
    await repo.log('slept 23:10 to 06:45', at: _morning(now));
    await repo.log(
      'napped for 20 min',
      at: DateTime(now.year, now.month, now.day, 15),
    );
    final container = ProviderContainer(overrides: illunisOverrides(store));
    addTearDown(container.dispose);
    addTearDown(store.dispose);
    final sleep = container.read(sleepRecordProvider);
    expect(sleep, isNotNull);
    expect(sleep!.durationHours, closeTo(7 + 35 / 60, 1e-6));
  });

  testWidgets('timeline announces the night, not the nap', (tester) async {
    final store = AppStore.memory();
    addTearDown(store.dispose);
    final now = DateTime.now();
    final repo = JournalRepository(store);
    await repo.log('slept 23:10 to 06:45', at: _morning(now));
    await repo.log(
      'napped for 20 min',
      at: DateTime(now.year, now.month, now.day, 15),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: illunisOverrides(store),
        child: const IllunisApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.bySemanticsLabel('Day timeline. Sleep 7h 35m'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  ProviderContainer containerWithBridge(
    AppStore store,
    String day,
    WearableDailyData? bridge,
  ) {
    final container = ProviderContainer(
      overrides: [
        ...illunisOverrides(store),
        civilDayProvider.overrideWith((ref) => dayKeyDate(day)),
        wearableDailyDataProvider(day).overrideWith(
          (ref) => Future.value(bridge),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(store.dispose);
    return container;
  }

  test('journal absent + bridge present renders a wearable band', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    final day = dayKey(now);
    final container = containerWithBridge(
      store,
      day,
      const WearableDailyData(sleepHours: 6.5),
    );
    await container.read(wearableDailyDataProvider(day).future);
    final sleep = container.read(sleepRecordProvider);
    expect(sleep, isNotNull);
    expect(sleep!.source, SleepSource.wearable);
    expect(sleep.asleepHours, closeTo(6.5, 1e-6));
  });

  test('journal present ignores the bridge (R5 longest sleep wins)', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    final day = dayKey(now);
    await JournalRepository(
      store,
    ).log('slept 23:10 to 06:45', at: _morning(now));
    final container = containerWithBridge(
      store,
      day,
      const WearableDailyData(sleepHours: 4.0),
    );
    await container.read(wearableDailyDataProvider(day).future);
    final sleep = container.read(sleepRecordProvider);
    expect(sleep, isNotNull);
    expect(sleep!.source, SleepSource.journal);
    expect(sleep.durationHours, closeTo(7 + 35 / 60, 1e-6));
  });

  test('both absent stays empty', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    final day = dayKey(now);
    final container = containerWithBridge(store, day, null);
    await container.read(wearableDailyDataProvider(day).future);
    expect(container.read(sleepRecordProvider), isNull);
  });
}
