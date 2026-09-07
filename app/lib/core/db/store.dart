import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'records.dart';

/// Device-canonical store. JSON on disk so every platform, including
/// Windows desktop and widget tests, can read and write without a native
/// SQLite dance. The shape matches the planned Drift tables so a later
/// migration is a copy, not a redesign.
class AppStore extends ChangeNotifier {
  AppStore._();

  factory AppStore.memory() => AppStore._();

  Profile profile = Profile(installId: newInstallId());
  final List<JournalEntry> journal = [];
  final List<StrengthSet> sets = [];
  final List<NutritionEntry> nutrition = [];
  final List<ActivityEntry> activities = [];
  final List<SleepEntry> sleeps = [];
  final List<WeightEntry> weights = [];
  final List<DaySummary> summaries = [];
  String? insightNote;
  String? insightKey;

  File? _file;

  Future<void> load() async {
    try {
      Directory dir;
      try {
        dir = await getApplicationSupportDirectory();
      } catch (_) {
        final home =
            Platform.environment['APPDATA'] ??
            Platform.environment['HOME'] ??
            Directory.systemTemp.path;
        dir = Directory(p.join(home, 'illunis'));
        if (!await dir.exists()) await dir.create(recursive: true);
      }
      _file = File(p.join(dir.path, 'illunis.json'));
      if (await _file!.exists()) {
        final raw =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _readMap(raw.cast<String, Object?>());
      }
    } catch (_) {
      _file = null;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    notifyListeners();
    final file = _file;
    if (file == null) return;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'journal': [for (final e in journal) e.toJson()],
    'sets': [for (final e in sets) e.toJson()],
    'nutrition': [for (final e in nutrition) e.toJson()],
    'activities': [for (final e in activities) e.toJson()],
    'sleeps': [for (final e in sleeps) e.toJson()],
    'weights': [for (final e in weights) e.toJson()],
    'summaries': [for (final e in summaries) e.toJson()],
    if (insightNote != null) 'insightNote': insightNote,
    if (insightKey != null) 'insightKey': insightKey,
  };

  void _readMap(Map<String, Object?> raw) {
    journal.clear();
    sets.clear();
    nutrition.clear();
    activities.clear();
    sleeps.clear();
    weights.clear();
    summaries.clear();
    if (raw['profile'] is Map) {
      profile = Profile.fromJson(
        (raw['profile'] as Map).cast<String, Object?>(),
      );
    }
    void loadList(String k, void Function(Map<String, Object?>) add) {
      final list = raw[k];
      if (list is! List) return;
      for (final e in list) {
        if (e is Map) add(e.cast<String, Object?>());
      }
    }

    loadList('journal', (j) => journal.add(JournalEntry.fromJson(j)));
    loadList('sets', (j) => sets.add(StrengthSet.fromJson(j)));
    loadList('nutrition', (j) => nutrition.add(NutritionEntry.fromJson(j)));
    loadList('activities', (j) => activities.add(ActivityEntry.fromJson(j)));
    loadList('sleeps', (j) => sleeps.add(SleepEntry.fromJson(j)));
    loadList('weights', (j) => weights.add(WeightEntry.fromJson(j)));
    loadList('summaries', (j) => summaries.add(DaySummary.fromJson(j)));
    insightNote = raw['insightNote'] as String?;
    insightKey = raw['insightKey'] as String?;
  }

  Future<void> putProfile(Profile p) async {
    profile = p;
    await _persist();
  }

  Future<JournalEntry> addJournal(JournalEntry e) async {
    journal.insert(0, e);
    await _persist();
    return e;
  }

  Future<void> addDerived({
    List<StrengthSet> newSets = const [],
    List<NutritionEntry> newNutrition = const [],
    List<ActivityEntry> newActivities = const [],
    List<SleepEntry> newSleeps = const [],
    List<WeightEntry> newWeights = const [],
  }) async {
    sets.addAll(newSets);
    nutrition.addAll(newNutrition);
    activities.addAll(newActivities);
    sleeps.addAll(newSleeps);
    weights.addAll(newWeights);
    await _persist();
  }

  Future<void> revertJournalEntry(String id) async {
    journal.removeWhere((e) => e.id == id);
    sets.removeWhere((e) => e.journalEntryId == id);
    nutrition.removeWhere((e) => e.journalEntryId == id);
    activities.removeWhere((e) => e.journalEntryId == id);
    sleeps.removeWhere((e) => e.journalEntryId == id);
    weights.removeWhere((e) => e.journalEntryId == id);
    await _persist();
  }

  Future<void> setKeepLocal(String id, bool excluded) async {
    final i = journal.indexWhere((e) => e.id == id);
    if (i < 0) return;
    journal[i] = journal[i].copyWith(excludedFromAi: excluded);
    await _persist();
  }

  Future<void> confirmNutrition(String id) async {
    final i = nutrition.indexWhere((e) => e.id == id);
    if (i < 0) return;
    nutrition[i] = nutrition[i].copyWith(confirmed: true);
    await _persist();
  }

  Future<void> confirmActivity(String id) async {
    final i = activities.indexWhere((e) => e.id == id);
    if (i < 0) return;
    activities[i] = activities[i].copyWith(confirmed: true);
    await _persist();
  }

  Future<void> dropNutrition(String id) async {
    nutrition.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> dropActivity(String id) async {
    activities.removeWhere((e) => e.id == id);
    await _persist();
  }

  /// Quality-only pages (`slept poorly`) do not invent hours. They mark
  /// the last night on this morning or the one before.
  Future<String?> attachSleepQuality({
    required String day,
    required double quality,
  }) async {
    final yesterday = dayKey(dayKeyDate(day).subtract(const Duration(days: 1)));
    var idx = -1;
    for (var i = sleeps.length - 1; i >= 0; i--) {
      if (sleeps[i].day == day) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      for (var i = sleeps.length - 1; i >= 0; i--) {
        if (sleeps[i].day == yesterday) {
          idx = i;
          break;
        }
      }
    }
    if (idx < 0) return null;
    sleeps[idx] = sleeps[idx].copyWith(quality: quality);
    await _persist();
    return sleeps[idx].day;
  }

  /// `woke at 6:45` finishes last night's bedtime. The night belongs to
  /// the morning they woke. Empty when there was nothing to finish.
  Future<Set<String>> completeSleep({
    required String day,
    required double endHours,
  }) async {
    final yesterday = dayKey(dayKeyDate(day).subtract(const Duration(days: 1)));
    var idx = -1;
    for (var i = sleeps.length - 1; i >= 0; i--) {
      if (!sleeps[i].isComplete && sleeps[i].day == day) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      for (var i = sleeps.length - 1; i >= 0; i--) {
        if (!sleeps[i].isComplete && sleeps[i].day == yesterday) {
          idx = i;
          break;
        }
      }
    }
    if (idx < 0) return {};
    var start = sleeps[idx].startHours;
    if (endHours < start) start -= 24;
    final hours = endHours - start;
    if (hours < 0.08 || hours > 16) return {};
    final from = sleeps[idx].day;
    sleeps[idx] = sleeps[idx].copyWith(
      day: day,
      startHours: start,
      endHours: endHours,
    );
    await _persist();
    return {from, day};
  }

  Future<void> putSummary(DaySummary s) async {
    summaries.removeWhere((e) => e.day == s.day);
    summaries.add(s);
    summaries.sort((a, b) => a.day.compareTo(b.day));
    await _persist();
  }

  Future<void> putInsight({String? note, String? key}) async {
    insightNote = note;
    insightKey = key;
    await _persist();
  }

  Future<void> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('not an object');
    }
    _readMap(decoded.cast<String, Object?>());
    await _persist();
  }

  Future<void> deleteAll() async {
    journal.clear();
    sets.clear();
    nutrition.clear();
    activities.clear();
    sleeps.clear();
    weights.clear();
    summaries.clear();
    insightNote = null;
    insightKey = null;
    await _persist();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String exportCsv() {
    final buf = StringBuffer('day,kind,label,value,confirmed\n');
    for (final e in journal) {
      buf.writeln('${e.day},journal,"${e.text.replaceAll('"', "'")}",,');
    }
    for (final e in sets) {
      buf.writeln(
        '${e.day},set,${e.exerciseName},${e.weightKg}x${e.reps}x${e.sets},1',
      );
    }
    for (final e in nutrition) {
      buf.writeln('${e.day},food,${e.label},${e.kcal},${e.confirmed ? 1 : 0}');
    }
    for (final e in activities) {
      buf.writeln(
        '${e.day},activity,${e.label},${e.distanceKm ?? ''} ${e.minutes ?? ''} ${e.kcal},${e.confirmed ? 1 : 0}',
      );
    }
    for (final e in sleeps) {
      if (!e.isComplete) continue;
      buf.writeln('${e.day},sleep,,${e.durationHours},1');
    }
    for (final e in weights) {
      buf.writeln('${e.day},weight,,${e.kg},1');
    }
    return buf.toString();
  }

  List<JournalEntry> entriesOn(String day) =>
      journal.where((e) => e.day == day).toList();

  DaySummary? summaryOn(String day) {
    for (final s in summaries) {
      if (s.day == day) return s;
    }
    return null;
  }

  SleepEntry? lastSleep() {
    final sorted = [
      for (final e in sleeps)
        if (e.isComplete) e,
    ]..sort((a, b) => b.day.compareTo(a.day));
    if (sorted.isEmpty) return null;
    return sorted.first;
  }

  WeightEntry? lastWeight() {
    if (weights.isEmpty) return null;
    final sorted = [...weights]..sort((a, b) => b.day.compareTo(a.day));
    return sorted.first;
  }

  /// Last logged mass on or before [day], in kilograms.
  double? weightOnOrBefore(String day) {
    WeightEntry? best;
    for (final w in weights) {
      if (w.day.compareTo(day) <= 0) {
        if (best == null || w.day.compareTo(best.day) > 0) best = w;
      }
    }
    return best?.kg;
  }
}
