// Regression tests verifying Phase D P1 fixes.
// Run explicitly: flutter test tool/astra_phase_d_audit_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:illunis/core/ai/transport.dart';
import 'package:illunis/core/db/records.dart';
import 'package:illunis/core/db/store.dart';
import 'package:illunis/core/journal/parser.dart';
import 'package:illunis/core/journal/repository.dart';
import 'package:illunis/core/state/app_providers.dart';
import 'package:illunis/core/i18n/strings.dart';
import 'package:illunis/features/settings/settings_sheet.dart';

void main() {
  final day = DateTime(2026, 9, 9, 12);
  ParsedJournal parse(String text) =>
      parseJournal(JournalEntry(id: 'probe', at: day, text: text));

  test('P1-3: invalid import does NOT clear existing records (atomic all-or-nothing)', () async {
    final store = AppStore.memory();
    await JournalRepository(store).log('weight 75 kg', at: day);
    await expectLater(store.importJson('{"journal":[{}]}'), throwsA(anything));
    expect(store.journal, isNotEmpty);
    expect(store.weights.single.kg, 75);
  });

  test(
    'P1-3: empty object import is rejected and imported consent does NOT transfer',
    () async {
      final store = AppStore.memory();
      await JournalRepository(store).log('weight 75 kg', at: day);
      await expectLater(store.importJson('{}'), throwsA(isA<FormatException>()));
      expect(store.journal, isNotEmpty);

      final originalInstallId = store.profile.installId;
      final donor = AppStore.memory();
      donor.profile = donor.profile.copyWith(
        aiConsentAt: day,
        ageAtLeast16: true,
      );
      await store.importJson(donor.exportJson());
      expect(store.profile.hasAiConsent, isFalse);
      expect(store.profile.installId, originalInstallId);
    },
  );

  test('D: Polish nap hours parsed correctly; mass comma decimal works', () {
    expect(parse('drzemka 2 godziny').sleeps.single.durationHours, 2);
    expect(parse('nap 2 hours').sleeps.single.durationHours, 2);
    expect(parse('waga 82,4 kg').weights.single.kg, 82.4);
  });

  test('D: short Polish genitive and fractional food quantity', () {
    expect(parse('zjadlem ryzu').nutrition.single.label, 'Rice');
    expect(parse('zjadlem ryz').nutrition.single.label, 'Rice');
    expect(parse('ate 1,5 banana').nutrition.single.kcal, closeTo(157.5, 1e-9));
  });

  testWidgets('D: settings delete row scrolls above Blade-sized safe inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2412);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: 72);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(AppStore.memory())],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSettingsSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(S.deleteAll));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text(S.deleteAll)).dy,
      lessThanOrEqualTo(780),
    );
    expect(tester.takeException(), isNull);
  });

  test('P1-6: activity with explicit kcal parses as activity, NOT food intake', () {
    final p = parse('ran 5 km in 30 min 400 kcal');
    expect(p.activities.single.kcal, 400);
    expect(p.nutrition, isEmpty);
  });

  test('P1-7: invalid sleep duration and zero set count are rejected', () {
    expect(parse('slept 99 hours').sleeps, isEmpty);
    expect(parse('bench 60 kg x 5 x 0').sets, isEmpty);
  });

  test('P1-8: sleep completion reverses when wake entry is reverted', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('went to bed at 23:00', at: DateTime(2026, 9, 8, 23));
    final wake = await repo.log('woke at 7:00', at: day);
    expect(store.sleeps.single.durationHours, 8);
    await repo.revert(wake.id);
    expect(store.sleeps.single.durationHours, 0);
    expect(store.sleeps.single.isComplete, isFalse);
  });

  test('P1-9: same-day mass correction returns latest logged mass', () async {
    final store = AppStore.memory();
    final repo = JournalRepository(store);
    await repo.log('weight 75 kg', at: day);
    await repo.log('weight 80 kg', at: day.add(const Duration(hours: 1)));
    expect(store.weightOnOrBefore('2026-09-09'), 80);
  });

  test('D: CSV comma in label is RFC 4180 escaped in quotes', () async {
    final store = AppStore.memory();
    await store.addDerived(
      newNutrition: [
        const NutritionEntry(
          id: 'n',
          journalEntryId: 'j',
          day: '2026-09-09',
          label: 'rice, beans',
          kcal: 300,
        ),
      ],
    );
    expect(store.exportCsv().split('\n')[1], '2026-09-09,food,"rice, beans",300.0,0');
  });

  test('P1-1: keep-local sleep is excluded from AI payload digest', () async {
    final payloads = <String>[];
    final client = MockClient((req) async {
      if (req.headers['x-illunis-call'] == 'dayDigest') {
        payloads.add((jsonDecode(req.body) as Map)['user'] as String);
      }
      return http.Response(jsonEncode({'raw': '{}'}), 200);
    });
    final store = AppStore.memory();
    store.profile = store.profile.copyWith(
      aiConsentAt: day,
      ageAtLeast16: true,
    );
    final repo = JournalRepository(
      store,
      transport: AiTransport(client: client, endpoint: 'https://audit.invalid'),
    );
    await repo.log('slept 8 hours', excludedFromAi: true, at: day);
    await repo.log('a quiet day', at: day);
    await Future<void>.delayed(Duration.zero);
    expect(payloads.single, contains('sleepHours=null'));
    expect(payloads.single, isNot(contains('sleepHours=8.0')));
    client.close();
  });

  test('P1-2: AI response does NOT resurrect derived records after delete all', () async {
    final response = Completer<http.Response>();
    final client = MockClient((req) async {
      if (req.headers['x-illunis-call'] == 'journalInterpretation') {
        return response.future;
      }
      return http.Response(jsonEncode({'raw': '{}'}), 200);
    });
    final store = AppStore.memory();
    store.profile = store.profile.copyWith(
      aiConsentAt: day,
      ageAtLeast16: true,
    );
    final repo = JournalRepository(
      store,
      transport: AiTransport(client: client, endpoint: 'https://audit.invalid'),
    );
    await repo.log('a quiet day', at: day);
    await store.deleteAll();
    response.complete(
      http.Response(
        jsonEncode({
          'raw': jsonEncode({'weightKg': 77}),
        }),
        200,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.journal, isEmpty);
    expect(store.weights, isEmpty);
    client.close();
  });
}
