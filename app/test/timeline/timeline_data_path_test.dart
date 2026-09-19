import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/journal/repository.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/state/civil_day.dart';
import 'package:illunis/core/state/sleep_record.dart';

ProviderContainer _container(AppStore store) {
  final c = ProviderContainer(overrides: illunisOverrides(store));
  addTearDown(c.dispose);
  addTearDown(store.dispose);
  return c;
}

void main() {
  test('H1: night 23:10->06:45 logged in the morning reaches sleep provider',
      () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    await JournalRepository(store).log(
      'slept 23:10 to 06:45',
      at: DateTime(now.year, now.month, now.day, 7, 5),
    );
    final c = _container(store);
    expect(c.read(sleepRecordProvider), isNotNull);
  });

  test('H2: a plain journal page today leaves a timeline hairline', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    await JournalRepository(store).log(
      'ate a big lunch',
      at: DateTime(now.year, now.month, now.day, 12, 30),
    );
    final c = _container(store);
    final marks = c.read(timelineMarksProvider);
    expect(marks, isNotEmpty);
  });

  test('H3a: entry just after midnight lands on the civil day', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    await JournalRepository(store).log(
      'midnight snack',
      at: DateTime(now.year, now.month, now.day, 0, 5),
    );
    final c = _container(store);
    expect(
      c.read(timelineMarksProvider),
      hasLength(store.journal.where((e) => e.day == dayKey(now)).length),
    );
    expect(c.read(timelineMarksProvider), isNotEmpty);
  });

  test('H3b: entry just before midnight lands on the civil day', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    await JournalRepository(store).log(
      'late night tea',
      at: DateTime(now.year, now.month, now.day, 23, 55),
    );
    final c = _container(store);
    expect(c.read(timelineMarksProvider), isNotEmpty);
  });

  test('H4: two-step bedtime + wake reaches the timeline', () async {
    final store = AppStore.memory();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await JournalRepository(store).log(
      'in bed at 23:10',
      at: DateTime(today.year, today.month, today.day, 23, 12).isAfter(now)
          ? today.subtract(const Duration(days: 1)).add(
              const Duration(hours: 23, minutes: 12),
            )
          : DateTime(today.year, today.month, today.day, 23, 12),
    );
    await JournalRepository(store).log(
      'woke at 6:45',
      at: DateTime(now.year, now.month, now.day, 7, 5),
    );
    final c = _container(store);
    expect(c.read(sleepRecordProvider), isNotNull);
  });

  test('H0: fresh empty store is correctly empty (no bug)', () async {
    final store = AppStore.memory();
    final c = _container(store);
    expect(c.read(sleepRecordProvider), isNull);
    expect(c.read(timelineMarksProvider), isEmpty);
    expect(c.read(civilDayProvider), isNotNull);
  });
}
