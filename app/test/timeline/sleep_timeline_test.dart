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

  test('synthetic staged wearable session spanning midnight plumbs phases to timeline', () async {
    final store = AppStore.memory();
    final day = '2026-09-19';
    final stages = [
      WearableSleepStage(
        start: DateTime(2026, 9, 18, 22, 30),
        end: DateTime(2026, 9, 18, 23, 0),
        stage: SleepStage.awake,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 18, 23, 0),
        end: DateTime(2026, 9, 19, 0, 30),
        stage: SleepStage.light,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 0, 30),
        end: DateTime(2026, 9, 19, 2, 0),
        stage: SleepStage.deep,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 2, 0),
        end: DateTime(2026, 9, 19, 3, 30),
        stage: SleepStage.rem,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 3, 30),
        end: DateTime(2026, 9, 19, 6, 0),
        stage: SleepStage.light,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 6, 0),
        end: DateTime(2026, 9, 19, 6, 30),
        stage: SleepStage.awake,
      ),
    ];
    final wearable = WearableDailyData(
      sleepHours: 8.0,
      sleepStart: DateTime(2026, 9, 18, 22, 30),
      sleepEnd: DateTime(2026, 9, 19, 6, 30),
      sleepStages: stages,
    );
    final container = containerWithBridge(store, day, wearable);
    await container.read(wearableDailyDataProvider(day).future);
    final sleep = container.read(sleepRecordProvider);

    expect(sleep, isNotNull);
    expect(sleep!.source, SleepSource.wearable);
    expect(sleep.startHours, closeTo(-1.5, 0.001));
    expect(sleep.endHours, closeTo(6.5, 0.001));
    expect(sleep.durationHours, closeTo(8.0, 0.001));
    // Asleep hours exclude 2 * 0.5h awake = 7.0h
    expect(sleep.asleepHours, closeTo(7.0, 0.001));
    expect(sleep.segments.length, 6);
    expect(sleep.segments[0].stage, SleepStage.awake);
    expect(sleep.segments[1].stage, SleepStage.light);
    expect(sleep.segments[2].stage, SleepStage.deep);
    expect(sleep.segments[3].stage, SleepStage.rem);
    expect(sleep.segments[4].stage, SleepStage.light);
    expect(sleep.segments[5].stage, SleepStage.awake);
  });

  test('synthetic staged wearable session entirely after midnight', () async {
    final store = AppStore.memory();
    final day = '2026-09-19';
    final stages = [
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 1, 0),
        end: DateTime(2026, 9, 19, 2, 0),
        stage: SleepStage.light,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 2, 0),
        end: DateTime(2026, 9, 19, 4, 0),
        stage: SleepStage.deep,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 4, 0),
        end: DateTime(2026, 9, 19, 6, 0),
        stage: SleepStage.rem,
      ),
      WearableSleepStage(
        start: DateTime(2026, 9, 19, 6, 0),
        end: DateTime(2026, 9, 19, 7, 0),
        stage: SleepStage.light,
      ),
    ];
    final wearable = WearableDailyData(
      sleepHours: 6.0,
      sleepStart: DateTime(2026, 9, 19, 1, 0),
      sleepEnd: DateTime(2026, 9, 19, 7, 0),
      sleepStages: stages,
    );
    final container = containerWithBridge(store, day, wearable);
    await container.read(wearableDailyDataProvider(day).future);
    final sleep = container.read(sleepRecordProvider);

    expect(sleep, isNotNull);
    expect(sleep!.startHours, closeTo(1.0, 0.001));
    expect(sleep.endHours, closeTo(7.0, 0.001));
    expect(sleep.segments.length, 4);
    expect(sleep.segments.every((s) => s.startHours >= 0), isTrue);
  });

  test('journal sleep overrides wearable and stays a single span without stage data', () async {
    final store = AppStore.memory();
    final now = DateTime(2026, 9, 19, 7, 5);
    final day = '2026-09-19';
    await JournalRepository(store).log('slept 23:10 to 06:45', at: now);

    final stages = [
      WearableSleepStage(
        start: DateTime(2026, 9, 18, 22, 30),
        end: DateTime(2026, 9, 19, 6, 30),
        stage: SleepStage.deep,
      ),
    ];
    final wearable = WearableDailyData(
      sleepHours: 8.0,
      sleepStages: stages,
    );
    final container = containerWithBridge(store, day, wearable);
    await container.read(wearableDailyDataProvider(day).future);
    final sleep = container.read(sleepRecordProvider);

    expect(sleep, isNotNull);
    expect(sleep!.source, SleepSource.journal);
    expect(sleep.segments, isEmpty); // Journal sleep stays a single span!
  });
}
