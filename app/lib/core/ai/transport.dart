import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../db/records.dart';
import 'prompts.dart';

const kAiEndpoint = String.fromEnvironment('ILLUNIS_AI_ENDPOINT');
const kAiToken = String.fromEnvironment('ILLUNIS_AI_TOKEN');

@immutable
class AiResult {
  const AiResult({this.raw, this.error});
  final String? raw;
  final String? error;
  bool get ok => raw != null && error == null;
}

/// The only socket. No model key lives here. The worker holds it.
class AiTransport {
  AiTransport({
    http.Client? client,
    this.endpoint = kAiEndpoint,
    this.token = kAiToken,
  }) : _injected = client;

  final http.Client? _injected;
  http.Client? _created;
  final String endpoint;
  final String token;

  http.Client get _client => _injected ?? (_created ??= http.Client());

  bool get configured => endpoint.isNotEmpty;

  Future<AiResult> call({
    required String name,
    required Profile profile,
    required String system,
    required String user,
    required Map<String, Object?> responseSchema,
    bool excludedFromAi = false,
  }) async {
    if (!configured) return const AiResult(error: 'no-endpoint');
    if (excludedFromAi) return const AiResult(error: 'keep-local');
    if (!profile.hasAiConsent) return const AiResult(error: 'no-consent');
    if (!profile.ageAtLeast16) return const AiResult(error: 'age');

    try {
      final res = await _client.post(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
          'x-illunis-install': profile.installId,
          'x-illunis-call': name,
        },
        body: jsonEncode({
          'call': name,
          'system': system,
          'user': user,
          'responseSchema': responseSchema,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AiResult(error: 'http-${res.statusCode}');
      }
      final body = jsonDecode(res.body);
      if (body is Map && body['raw'] is String) {
        return AiResult(raw: body['raw'] as String);
      }
      return const AiResult(error: 'shape');
    } catch (e) {
      return AiResult(error: e.toString());
    }
  }

  Future<AiResult> interpretJournal({
    required Profile profile,
    required JournalEntry entry,
  }) {
    return call(
      name: 'journalInterpretation',
      profile: profile,
      system: kJournalSystem,
      user: entry.text,
      responseSchema: kJournalSchema,
      excludedFromAi: entry.excludedFromAi,
    );
  }

  Future<AiResult> dayDigest({required Profile profile, required String user}) {
    return call(
      name: 'dayDigest',
      profile: profile,
      system: kDayDigestSystem,
      user: user,
      responseSchema: kDayDigestSchema,
    );
  }

  Future<AiResult> patternInsight({
    required Profile profile,
    required String user,
  }) {
    return call(
      name: 'patternInsight',
      profile: profile,
      system: kPatternInsightSystem,
      user: user,
      responseSchema: kPatternInsightSchema,
    );
  }
}

Map<String, Object?>? decodeRawJson(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is Map<String, dynamic>) return v.cast<String, Object?>();
    if (v is Map) return v.cast<String, Object?>();
  } catch (_) {}
  return null;
}
