import 'dart:async';

import '../ai/transport.dart';
import '../db/records.dart';
import '../db/store.dart';
import '../fitness/disciplines.dart';
import '../fitness/format.dart';
import '../fitness/session.dart';
import '../health/rollups.dart';
import '../journal/parser.dart';
import '../journal/stamp.dart';
import '../nutrition/foods.dart';
import '../patterns/sweep.dart';
import '../strength/canon.dart';
import '../strength/one_rm.dart';

class JournalRepository {
  JournalRepository(this.store, {AiTransport? transport})
    : transport = transport ?? AiTransport();

  final AppStore store;
  final AiTransport transport;

  double get _bodyKg => store.lastWeight()?.kg ?? 75;

  Future<JournalEntry> log(
    String text, {
    bool excludedFromAi = false,
    DateTime? at,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('empty');
    }
    final stamped = stampJournalLine(trimmed);
    if (stamped.text.isEmpty) {
      throw ArgumentError('empty');
    }
    var when = stamped.apply(at ?? DateTime.now());
    var entry = JournalEntry(
      id: newId(),
      at: when,
      text: stamped.text,
      excludedFromAi: excludedFromAi,
    );
    var parsed = parseJournal(
      entry,
      bodyKg: _bodyKg,
      units: store.profile.units,
    );
    final shifted = _nightBelongs(when, stamped, parsed);
    if (shifted != when) {
      entry = JournalEntry(
        id: entry.id,
        at: shifted,
        text: entry.text,
        excludedFromAi: excludedFromAi,
      );
      parsed = parseJournal(entry, bodyKg: _bodyKg, units: store.profile.units);
    }
    await store.transaction(() async {
      await store.addJournal(entry);
      await store.addDerived(
        newSets: parsed.sets,
        newNutrition: parsed.nutrition,
        newActivities: parsed.activities,
        newSleeps: parsed.sleeps,
        newWeights: parsed.weights,
      );
      final days = <String>{entry.day};
      if (parsed.sleeps.isEmpty) {
        final wake = sleepWakeHoursOf(entry.text);
        if (wake != null) {
          days.addAll(
            await store.completeSleep(
              day: entry.day,
              endHours: wake,
              wakeJournalEntryId: entry.id,
            ),
          );
        }
        final q = sleepQualityOf(entry.text);
        if (q != null) {
          final patched = await store.attachSleepQuality(
            day: entry.day,
            quality: q,
            qualityJournalEntryId: entry.id,
          );
          if (patched != null) days.add(patched);
        }
      }
      await recomputeSummaries(store, days: days);
    });
    if (!excludedFromAi) {
      unawaited(_maybeInsights());
      if (transport.configured &&
          store.profile.hasAiConsent &&
          store.profile.ageAtLeast16) {
        unawaited(_enrich(entry, parsed));
        unawaited(_maybeDigest(entry.day));
      }
    }
    return entry;
  }

  Future<JournalEntry?> revert(String id) async {
    JournalEntry? hit;
    for (final e in store.journal) {
      if (e.id == id) {
        hit = e;
        break;
      }
    }
    final affectedDays = await store.revertJournalEntry(id);
    if (affectedDays.isNotEmpty) {
      await recomputeSummaries(store, days: affectedDays);
    }
    unawaited(_maybeInsights());
    return hit;
  }

  Future<void> setKeepLocal(String id, bool excluded) async {
    await store.setKeepLocal(id, excluded);
  }

  Future<void> confirmFood(String id) async {
    String? day;
    for (final e in store.nutrition) {
      if (e.id == id) {
        day = e.day;
        break;
      }
    }
    await store.confirmNutrition(id);
    if (day != null) await recomputeSummaries(store, days: {day});
  }

  Future<void> confirmActivity(String id) async {
    String? day;
    for (final e in store.activities) {
      if (e.id == id) {
        day = e.day;
        break;
      }
    }
    await store.confirmActivity(id);
    if (day != null) await recomputeSummaries(store, days: {day});
  }

  Future<void> confirmAll(String day) async {
    for (final e in [...store.nutrition]) {
      if (e.day == day && !e.confirmed) await store.confirmNutrition(e.id);
    }
    for (final e in [...store.activities]) {
      if (e.day == day && !e.confirmed) await store.confirmActivity(e.id);
    }
    await recomputeSummaries(store, days: {day});
  }

  Future<void> dropFood(String id) async {
    String? day;
    for (final e in store.nutrition) {
      if (e.id == id) {
        day = e.day;
        break;
      }
    }
    await store.dropNutrition(id);
    if (day != null) await recomputeSummaries(store, days: {day});
  }

  Future<void> dropActivity(String id) async {
    String? day;
    for (final e in store.activities) {
      if (e.id == id) {
        day = e.day;
        break;
      }
    }
    await store.dropActivity(id);
    if (day != null) await recomputeSummaries(store, days: {day});
  }

  Future<void> _enrich(JournalEntry entry, ParsedJournal local) async {
    final result = await transport.interpretJournal(
      profile: store.profile,
      entry: entry,
    );
    if (!result.ok) return;
    if (!store.profile.hasAiConsent || !store.profile.ageAtLeast16) return;
    final current = store.journal.where((e) => e.id == entry.id).firstOrNull;
    if (current == null || current.excludedFromAi) return;

    final json = decodeRawJson(result.raw!);
    if (json == null) return;
    final extra = _fromAi(entry, json, local);
    if (extra.isEmpty) return;

    if (!store.journal.any((e) => e.id == entry.id && !e.excludedFromAi)) return;

    await store.transaction(() async {
      await store.addDerived(
        newSets: extra.sets,
        newNutrition: extra.nutrition,
        newActivities: extra.activities,
        newSleeps: extra.sleeps,
        newWeights: extra.weights,
      );
      if (extra.sleeps.isEmpty && local.sleeps.isEmpty && json['sleep'] is Map) {
        final q = ((json['sleep'] as Map)['quality'] as num?)?.toDouble();
        if (q != null) {
          await store.attachSleepQuality(
            day: entry.day,
            quality: q.clamp(0.0, 1.0).toDouble(),
            qualityJournalEntryId: entry.id,
          );
        }
      }
      await recomputeSummaries(store, days: {entry.day});
    });
    unawaited(_maybeInsights());
  }

  Future<void> _maybeDigest(String day) async {
    final existing = store.summaryOn(day);
    if (existing?.digestSource == 'ai' && (existing?.digest ?? '').isNotEmpty) {
      return;
    }
    final s = summaryForAi(store, day);
    final user =
        'day $day sleepHours=${s.sleepHours} strain=${s.strain} '
        'intake=${s.intakeKcal} volumeKg=${s.volumeKg} sets=${s.sets} '
        'moveMin=${s.moveMinutes} distanceKm=${s.distanceKm} '
        'runKmh=${s.runSpeedKmh} energyKcal=${s.energyKcal}';
    final result = await transport.dayDigest(
      profile: store.profile,
      user: user,
    );
    if (!result.ok) return;
    if (!store.profile.hasAiConsent || !store.profile.ageAtLeast16) return;
    final json = decodeRawJson(result.raw!);
    final sentence = json?['sentence'] as String?;
    if (sentence == null || sentence.trim().isEmpty || sentence.length > 180) {
      return;
    }
    final latest = store.summaryOn(day);
    if (latest == null) return;
    await store.putSummary(
      latest.copyWith(digest: sentence.trim(), digestSource: 'ai'),
    );
  }

  Future<void> _maybeInsights() async {
    if (!transport.configured) return;
    if (!store.profile.hasAiConsent || !store.profile.ageAtLeast16) return;
    final aiSummaries = [
      for (final s in store.summaries) summaryForAi(store, s.day),
    ];
    final board = insightBoard(aiSummaries);
    if (board.findings.isEmpty) {
      if (store.insightNote != null) {
        await store.putInsight();
      }
      return;
    }
    final key = board.findings
        .map(
          (f) =>
              '${f.id}:${f.correlation.n}:${f.correlation.r.toStringAsFixed(2)}',
        )
        .join('|');
    if (store.insightKey == key && (store.insightNote ?? '').isNotEmpty) {
      return;
    }
    final buf = StringBuffer();
    for (final f in board.findings.take(6)) {
      buf.writeln(
        '${f.pairLabel} r=${f.correlation.r.toStringAsFixed(2)} n=${f.correlation.n}',
      );
      buf.writeln(f.sentence);
      if (f.evidence != null) buf.writeln(f.evidence);
      buf.writeln();
    }
    final result = await transport.patternInsight(
      profile: store.profile,
      user: buf.toString(),
    );
    if (!result.ok) return;
    if (!store.profile.hasAiConsent || !store.profile.ageAtLeast16) return;
    final currentBoard = insightBoard([
      for (final s in store.summaries) summaryForAi(store, s.day),
    ]);
    final currentKey = currentBoard.findings
        .map(
          (f) =>
              '${f.id}:${f.correlation.n}:${f.correlation.r.toStringAsFixed(2)}',
        )
        .join('|');
    if (currentKey != key) return;

    final json = decodeRawJson(result.raw!);
    final sentence = json?['sentence'] as String?;
    if (sentence == null || sentence.trim().isEmpty || sentence.length > 240) {
      return;
    }
    await store.putInsight(note: sentence.trim(), key: key);
  }

  ParsedJournal _fromAi(
    JournalEntry entry,
    Map<String, Object?> json,
    ParsedJournal local,
  ) {
    final sets = <StrengthSet>[];
    final nutrition = <NutritionEntry>[];
    final activities = <ActivityEntry>[];
    final sleeps = <SleepEntry>[];
    final weights = <WeightEntry>[];

    if (local.sets.isEmpty && json['sets'] is List) {
      for (final raw in json['sets'] as List) {
        if (raw is! Map) continue;
        final m = raw.cast<String, Object?>();
        final name = m['exercise'] as String? ?? '';
        final w = (m['weightKg'] as num?)?.toDouble();
        final reps = (m['reps'] as num?)?.toInt();
        final nSets = (m['sets'] as num?)?.toInt() ?? 1;
        if (name.isEmpty || w == null || reps == null) continue;
        if (!w.isFinite || w <= 0 || w > 500 || reps < 1 || reps > 40 || nSets < 1 || nSets > 50) continue;
        final resolved = resolveExercise(name);
        sets.add(
          StrengthSet(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            exerciseId: resolved.exercise?.id ?? 'unknown',
            exerciseName: resolved.name,
            weightKg: w,
            reps: reps,
            sets: nSets,
            epley1rm: epley1rm(w, reps),
            brzycki1rm: brzycki1rm(w, reps),
            rpe: (m['rpe'] as num?)?.toDouble(),
          ),
        );
      }
    }

    if (json['foods'] is List) {
      for (final raw in json['foods'] as List) {
        if (raw is! Map) continue;
        final m = raw.cast<String, Object?>();
        final label = m['label'] as String? ?? '';
        final kcal = (m['kcal'] as num?)?.toDouble();
        if (label.isEmpty || kcal == null || !kcal.isFinite || kcal <= 0 || kcal > 4000) continue;
        final already = local.nutrition.any(
          (e) => e.label.toLowerCase() == label.toLowerCase(),
        );
        if (already) continue;
        final estimate = m['estimate'] as bool? ?? true;
        final known = lookupFood(label);
        double? cleanMacro(num? val) {
          if (val == null) return null;
          final d = val.toDouble();
          return (d.isFinite && d >= 0 && d <= 1000) ? d : null;
        }
        final prot = cleanMacro(m['proteinG'] as num?) ?? known?.proteinG;
        final carbs = cleanMacro(m['carbsG'] as num?) ?? known?.carbsG;
        final fat = cleanMacro(m['fatG'] as num?) ?? known?.fatG;
        final isConfirmed = !estimate && known != null;
        nutrition.add(
          NutritionEntry(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            label: known?.label ?? label,
            kcal: kcal,
            proteinG: prot,
            carbsG: carbs,
            fatG: fat,
            confirmed: isConfirmed,
            source: isConfirmed ? 'ai' : 'ai-estimate',
          ),
        );
      }
    }

    if (json['activities'] is List) {
      for (final raw in json['activities'] as List) {
        if (raw is! Map) continue;
        final m = raw.cast<String, Object?>();
        final label = m['label'] as String? ?? m['discipline'] as String? ?? '';
        if (label.isEmpty) continue;
        final resolved = resolveDiscipline(m['discipline'] as String? ?? label);
        final disc = resolved.discipline;
        final id = disc?.id ?? 'other';
        final already = local.activities.any(
          (e) =>
              e.disciplineId == id ||
              e.label.toLowerCase() == (disc?.label ?? label).toLowerCase(),
        );
        if (already) continue;
        double? km = (m['distanceKm'] as num?)?.toDouble();
        final meters = (m['distanceM'] as num?)?.toDouble();
        final miles = (m['miles'] as num?)?.toDouble();
        if (km == null && meters != null) km = meters / 1000;
        if (km == null && miles != null) km = miles * 1.609344;
        if (km != null && (km <= 0 || km > 400)) km = null;
        var minutes = (m['minutes'] as num?)?.toDouble();
        final pace = parsePace(m['pace'] as String?);
        if (minutes == null && pace != null && km != null && km > 0) {
          minutes = (pace * km) / 60;
        }
        if (minutes == null && km != null && (disc?.cruiseKmPerHour ?? 0) > 0) {
          minutes = (km / disc!.cruiseKmPerHour!) * 60;
        }
        if (minutes != null && (minutes <= 0 || minutes > 16 * 60)) {
          minutes = null;
        }
        var kcal = (m['kcal'] as num?)?.toDouble();
        final wasSynthesized = (m['kcal'] == null) || (m['minutes'] == null && (km != null || pace != null));
        if (kcal == null && minutes != null && disc != null) {
          kcal = disc.met * _bodyKg * (minutes / 60);
        }
        if (kcal == null || !kcal.isFinite || kcal <= 0 || kcal > 4000) continue;
        final estimate = (m['estimate'] as bool? ?? true) || wasSynthesized;
        final rpe = (m['rpe'] as num?)?.toDouble();
        final hr = (m['hr'] as num?)?.toDouble();
        activities.add(
          ActivityEntry(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            label: disc?.label ?? label,
            disciplineId: id,
            kcal: kcal,
            minutes: minutes,
            distanceKm: km,
            paceSecPerKm: disc != null && disc.tracksPace
                ? (pace ??
                      (km != null && minutes != null
                          ? paceSecPerKm(km: km, minutes: minutes)
                          : null))
                : null,
            rpe: rpe != null && rpe >= 1 && rpe <= 10 ? rpe : null,
            hrAvg: hr != null && hr >= 40 && hr <= 220 ? hr : null,
            effort: normalizeEffort(m['effort'] as String?),
            confirmed: !estimate,
            source: estimate ? 'ai-estimate' : 'ai',
          ),
        );
      }
    }

    if (local.sleeps.isEmpty && json['sleep'] is Map) {
      final m = (json['sleep'] as Map).cast<String, Object?>();
      final start = (m['startHours'] as num?)?.toDouble();
      final end = (m['endHours'] as num?)?.toDouble();
      if (start != null &&
          end != null &&
          start.isFinite &&
          end.isFinite &&
          end - start >= 0.08 &&
          end - start <= 16) {
        final q = (m['quality'] as num?)?.toDouble();
        sleeps.add(
          SleepEntry(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            startHours: start,
            endHours: end,
            quality: q?.clamp(0.0, 1.0).toDouble(),
          ),
        );
      }
    }

    if (local.weights.isEmpty && json['weightKg'] is num) {
      final kg = (json['weightKg'] as num).toDouble();
      if (kg.isFinite && kg >= 25 && kg <= 350) {
        weights.add(
          WeightEntry(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            kg: kg,
          ),
        );
      }
    }

    return ParsedJournal(
      sets: sets,
      nutrition: nutrition,
      activities: activities,
      sleeps: sleeps,
      weights: weights,
    );
  }
}

/// An evening bedtime logged in the morning is last night, not tonight.
DateTime _nightBelongs(
  DateTime when,
  StampedLine stamped,
  ParsedJournal parsed,
) {
  if (stamped.daysBack != 0) return when;
  if (when.hour >= 12) return when;
  if (parsed.sleeps.length != 1) return when;
  final night = parsed.sleeps.single;
  if (night.isComplete) return when;
  if (night.startHours < 18) return when;
  final prev = DateTime(
    when.year,
    when.month,
    when.day,
  ).subtract(const Duration(days: 1));
  final start = night.startHours;
  var h = start.floor();
  var min = ((start - h) * 60).round();
  if (min == 60) {
    h += 1;
    min = 0;
  }
  if (h >= 24) h -= 24;
  return DateTime(prev.year, prev.month, prev.day, h, min);
}
