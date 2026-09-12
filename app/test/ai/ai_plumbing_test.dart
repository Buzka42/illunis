import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:illunis/core/ai/prompts.dart';
import 'package:illunis/core/ai/transport.dart';
import 'package:illunis/core/db/records.dart';

void main() {
  final profile = Profile(
    installId: '0123456789abcdef0123456789abcdef',
    aiConsentAt: DateTime(2026, 9, 1),
    ageAtLeast16: true,
  );

  group('Prompt schemas and systems', () {
    test('kRestednessSystem and kRestednessSchema are configured', () {
      expect(kRestednessSystem, isNotEmpty);
      expect(kRestednessSchema['type'], 'object');
      final props = kRestednessSchema['properties'] as Map<String, Object?>;
      expect(props.containsKey('score'), isTrue);
      expect(props.containsKey('reason'), isTrue);
      expect(kRestednessSchema['required'], contains('score'));
    });

    test('kDayDigestSystem and kDayDigestSchema are configured', () {
      expect(kDayDigestSystem, isNotEmpty);
      expect(kDayDigestSchema['type'], 'object');
      final props = kDayDigestSchema['properties'] as Map<String, Object?>;
      expect(props.containsKey('sentence'), isTrue);
      expect(kDayDigestSchema['required'], contains('sentence'));
    });
  });

  group('AiTransport plumbing for restedness and dayDigest', () {
    test('restedness makes well-formed worker call and decodes valid response', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://worker.test');
        expect(request.headers['x-illunis-call'], 'restedness');
        expect(request.headers['x-illunis-install'], profile.installId);
        expect(request.headers['authorization'], 'Bearer test-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['call'], 'restedness');
        expect(body['system'], kRestednessSystem);
        expect(body['responseSchema'], isNotNull);

        return http.Response(
          jsonEncode({'raw': '{"score": 0.88, "reason": "Consistent 8h sleep"}'}),
          200,
        );
      });

      final transport = AiTransport(
        client: client,
        endpoint: 'https://worker.test',
        token: 'test-token',
      );
      final result = await transport.restedness(
        profile: profile,
        user: 'Sleep: 8.0h, Quality: 0.9, RHR: 52 bpm',
      );

      expect(result.ok, isTrue);
      expect(result.error, isNull);
      final decoded = decodeRawJson(result.raw!);
      expect(decoded, isNotNull);
      expect(decoded!['score'], 0.88);
      expect(decoded['reason'], 'Consistent 8h sleep');
    });

    test('dayDigest makes well-formed worker call and decodes valid response', () async {
      final client = MockClient((request) async {
        expect(request.headers['x-illunis-call'], 'dayDigest');

        return http.Response(
          jsonEncode({'raw': '{"sentence": "Morning 5k run followed by a rest evening."}'}),
          200,
        );
      });

      final transport = AiTransport(
        client: client,
        endpoint: 'https://worker.test',
        token: 'test-token',
      );
      final result = await transport.dayDigest(
        profile: profile,
        user: 'Movement: 5k run in 25 min',
      );

      expect(result.ok, isTrue);
      final decoded = decodeRawJson(result.raw!);
      expect(decoded!['sentence'], 'Morning 5k run followed by a rest evening.');
    });

    test('fails closed when worker returns 429 meter or 500 error', () async {
      final rateLimitedClient = MockClient((request) async {
        return http.Response('meter', 429);
      });

      final transport = AiTransport(
        client: rateLimitedClient,
        endpoint: 'https://worker.test',
        token: 'test-token',
      );
      final res = await transport.restedness(
        profile: profile,
        user: 'Sleep data',
      );

      expect(res.ok, isFalse);
      expect(res.error, 'http-429');
    });

    test('fails closed on network exception', () async {
      final errorClient = MockClient((request) async {
        throw Exception('connection refused');
      });

      final transport = AiTransport(
        client: errorClient,
        endpoint: 'https://worker.test',
        token: 'test-token',
      );
      final res = await transport.restedness(
        profile: profile,
        user: 'Sleep data',
      );

      expect(res.ok, isFalse);
      expect(res.error, contains('connection refused'));
    });
  });
}
