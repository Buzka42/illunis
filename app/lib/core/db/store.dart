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
  final List<StepEntry> steps = [];
  final List<DaySummary> summaries = [];
  String? insightNote;
  String? insightKey;

  File? _file;
  String? lastPersistenceError;
  int revision = 0;
  bool _inBatch = false;
  bool _batchDirty = false;

  Future<T> transaction<T>(Future<T> Function() action) async {
    final wasInBatch = _inBatch;
    _inBatch = true;
    try {
      return await action();
    } finally {
      if (!wasInBatch) {
        _inBatch = false;
        if (_batchDirty) {
          _batchDirty = false;
          await _persist();
        }
      }
    }
  }

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
      final bakFile = File(p.join(dir.path, 'illunis.json.bak'));
      Map<String, dynamic>? raw;
      if (await _file!.exists()) {
        try {
          raw = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        } catch (e) {
          lastPersistenceError = 'Failed reading illunis.json: $e';
          if (await bakFile.exists()) {
            try {
              raw =
                  jsonDecode(await bakFile.readAsString())
                      as Map<String, dynamic>;
            } catch (_) {}
          }
        }
      } else if (await bakFile.exists()) {
        try {
          raw =
              jsonDecode(await bakFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (raw != null) {
        _readMap(raw.cast<String, Object?>());
      }
    } catch (e) {
      lastPersistenceError = e.toString();
      // Keep _file assigned if available so future writes can still work.
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    revision++;
    notifyListeners();
    if (_inBatch) {
      _batchDirty = true;
      return;
    }
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(toJson());
      final dir = file.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      final tmpFile = File('${file.path}.tmp');
      final bakFile = File('${file.path}.bak');
      await tmpFile.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        try {
          if (await bakFile.exists()) await bakFile.delete();
          await file.copy(bakFile.path);
        } catch (_) {}
      }
      if (Platform.isWindows) {
        if (await file.exists()) await file.delete();
        await tmpFile.rename(file.path);
      } else {
        await tmpFile.rename(file.path);
      }
      lastPersistenceError = null;
    } catch (e) {
      lastPersistenceError = e.toString();
    }
  }

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'journal': [for (final e in journal) e.toJson()],
    'sets': [for (final e in sets) e.toJson()],
    'nutrition': [for (final e in nutrition) e.toJson()],
    'activities': [for (final e in activities) e.toJson()],
    'sleeps': [for (final e in sleeps) e.toJson()],
    'weights': [for (final e in weights) e.toJson()],
    'steps': [for (final e in steps) e.toJson()],
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
    steps.clear();
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
    loadList('steps', (j) => steps.add(StepEntry.fromJson(j)));
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
    List<StepEntry> newSteps = const [],
  }) async {
    sets.addAll(newSets);
    nutrition.addAll(newNutrition);
    activities.addAll(newActivities);
    sleeps.addAll(newSleeps);
    weights.addAll(newWeights);
    steps.addAll(newSteps);
    await _persist();
  }

  Future<Set<String>> revertJournalEntry(String id) async {
    final affectedDays = <String>{};
    for (final e in journal.where((e) => e.id == id)) {
      affectedDays.add(e.day);
    }
    journal.removeWhere((e) => e.id == id);
    for (final s in sets.where((e) => e.journalEntryId == id)) {
      affectedDays.add(s.day);
    }
    sets.removeWhere((e) => e.journalEntryId == id);
    for (final n in nutrition.where((e) => e.journalEntryId == id)) {
      affectedDays.add(n.day);
    }
    nutrition.removeWhere((e) => e.journalEntryId == id);
    for (final a in activities.where((e) => e.journalEntryId == id)) {
      affectedDays.add(a.day);
    }
    activities.removeWhere((e) => e.journalEntryId == id);
    for (final w in weights.where((e) => e.journalEntryId == id)) {
      affectedDays.add(w.day);
    }
    weights.removeWhere((e) => e.journalEntryId == id);
    for (final st in steps.where((e) => e.journalEntryId == id)) {
      affectedDays.add(st.day);
    }
    steps.removeWhere((e) => e.journalEntryId == id);

    final remainingSleeps = <SleepEntry>[];
    for (final s in sleeps) {
      if (s.journalEntryId == id) {
        affectedDays.add(s.day);
        if (s.originalDay != null) affectedDays.add(s.originalDay!);
      } else {
        var modified = s;
        if (s.wakeJournalEntryId == id) {
          affectedDays.add(s.day);
          if (s.originalDay != null) affectedDays.add(s.originalDay!);
          final start = s.originalStartHours ?? s.startHours;
          modified = modified.copyWith(
            day: s.originalDay ?? s.day,
            startHours: start,
            endHours: start,
            clearWake: true,
            clearOriginalDay: true,
            clearOriginalStartHours: true,
          );
        }
        if (s.qualityJournalEntryId == id) {
          affectedDays.add(s.day);
          modified = modified.copyWith(
            clearQuality: true,
            clearQualityJournalEntryId: true,
          );
        }
        remainingSleeps.add(modified);
      }
    }
    sleeps
      ..clear()
      ..addAll(remainingSleeps);

    await _persist();
    return affectedDays;
  }

  Future<void> setKeepLocal(String id, bool excluded) async {
    final i = journal.indexWhere((e) => e.id == id);
    if (i < 0) return;
    journal[i] = journal[i].copyWith(excludedFromAi: excluded);
    await _persist();
  }

  bool isAiEligible(String journalEntryId) {
    final entry = journal.where((e) => e.id == journalEntryId).firstOrNull;
    if (entry == null) return false;
    return !entry.excludedFromAi;
  }

  bool isSleepAiEligible(SleepEntry sleep) {
    if (!isAiEligible(sleep.journalEntryId)) return false;
    if (sleep.wakeJournalEntryId != null &&
        !isAiEligible(sleep.wakeJournalEntryId!)) {
      return false;
    }
    if (sleep.qualityJournalEntryId != null &&
        !isAiEligible(sleep.qualityJournalEntryId!)) {
      return false;
    }
    return true;
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
    String? qualityJournalEntryId,
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
    sleeps[idx] = sleeps[idx].copyWith(
      quality: quality,
      qualityJournalEntryId: qualityJournalEntryId,
    );
    await _persist();
    return sleeps[idx].day;
  }

  /// `woke at 6:45` finishes last night's bedtime. The night belongs to
  /// the morning they woke. Empty when there was nothing to finish.
  Future<Set<String>> completeSleep({
    required String day,
    required double endHours,
    String? wakeJournalEntryId,
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
    final originalStart = sleeps[idx].startHours;
    var start = originalStart;
    if (endHours < start) start -= 24;
    final hours = endHours - start;
    if (hours < 0.08 || hours > 16) return {};
    final from = sleeps[idx].day;
    sleeps[idx] = sleeps[idx].copyWith(
      day: day,
      startHours: start,
      endHours: endHours,
      wakeJournalEntryId: wakeJournalEntryId,
      originalDay: from,
      originalStartHours: originalStart,
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
    final map = decoded.cast<String, Object?>();
    final hasAnyPayload =
        map.containsKey('journal') ||
        map.containsKey('sets') ||
        map.containsKey('nutrition') ||
        map.containsKey('activities') ||
        map.containsKey('sleeps') ||
        map.containsKey('weights') ||
        map.containsKey('summaries') ||
        map.containsKey('profile');
    if (!hasAnyPayload) {
      throw const FormatException('Empty or unrecognized illunis backup');
    }

    final tempJournal = <JournalEntry>[];
    final tempSets = <StrengthSet>[];
    final tempNutrition = <NutritionEntry>[];
    final tempActivities = <ActivityEntry>[];
    final tempSleeps = <SleepEntry>[];
    final tempWeights = <WeightEntry>[];
    final tempSummaries = <DaySummary>[];

    void parseList(String key, void Function(Map<String, Object?>) adder) {
      final list = map[key];
      if (list == null) return;
      if (list is! List) throw FormatException('Field "$key" must be a list');
      for (final item in list) {
        if (item is! Map) {
          throw FormatException('Item in "$key" must be an object');
        }
        adder(item.cast<String, Object?>());
      }
    }

    final tempSteps = <StepEntry>[];
    parseList('journal', (j) => tempJournal.add(JournalEntry.fromJson(j)));
    parseList('sets', (j) => tempSets.add(StrengthSet.fromJson(j)));
    parseList(
      'nutrition',
      (j) => tempNutrition.add(NutritionEntry.fromJson(j)),
    );
    parseList(
      'activities',
      (j) => tempActivities.add(ActivityEntry.fromJson(j)),
    );
    parseList('sleeps', (j) => tempSleeps.add(SleepEntry.fromJson(j)));
    parseList('weights', (j) => tempWeights.add(WeightEntry.fromJson(j)));
    parseList('steps', (j) => tempSteps.add(StepEntry.fromJson(j)));
    parseList('summaries', (j) => tempSummaries.add(DaySummary.fromJson(j)));

    Profile newProfile = profile;
    if (map['profile'] is Map) {
      final importedProfile = Profile.fromJson(
        (map['profile'] as Map).cast<String, Object?>(),
      );
      newProfile = profile.copyWith(
        units: importedProfile.units,
        homePlace: importedProfile.homePlace,
        latitudeDeg: importedProfile.latitudeDeg,
        longitudeDeg: importedProfile.longitudeDeg,
      );
    }

    journal
      ..clear()
      ..addAll(tempJournal);
    sets
      ..clear()
      ..addAll(tempSets);
    nutrition
      ..clear()
      ..addAll(tempNutrition);
    activities
      ..clear()
      ..addAll(tempActivities);
    sleeps
      ..clear()
      ..addAll(tempSleeps);
    weights
      ..clear()
      ..addAll(tempWeights);
    steps
      ..clear()
      ..addAll(tempSteps);
    summaries
      ..clear()
      ..addAll(tempSummaries);
    profile = newProfile;
    insightNote = map['insightNote'] as String?;
    insightKey = map['insightKey'] as String?;

    await _persist();
  }

  Future<void> deleteAll() async {
    profile = profile.copyWith(
      insightDismissalDay: '',
      dismissedInsightIds: const [],
    );
    journal.clear();
    sets.clear();
    nutrition.clear();
    activities.clear();
    sleeps.clear();
    weights.clear();
    steps.clear();
    summaries.clear();
    insightNote = null;
    insightKey = null;
    await _persist();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  static String _csvCell(Object? value) {
    if (value == null) return '';
    var s = value.toString();
    if (s.startsWith('=') ||
        s.startsWith('+') ||
        s.startsWith('-') ||
        s.startsWith('@') ||
        s.startsWith('\t')) {
      s = "'$s";
    }
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String exportCsv() {
    final buf = StringBuffer('day,kind,label,value,confirmed\n');
    for (final e in journal) {
      buf.writeln('${_csvCell(e.day)},journal,${_csvCell(e.text)},,');
    }
    for (final e in sets) {
      buf.writeln(
        '${_csvCell(e.day)},set,${_csvCell(e.exerciseName)},${_csvCell('${e.weightKg}x${e.reps}x${e.sets}')},1',
      );
    }
    for (final e in nutrition) {
      buf.writeln(
        '${_csvCell(e.day)},food,${_csvCell(e.label)},${e.kcal},${e.confirmed ? 1 : 0}',
      );
    }
    for (final e in activities) {
      final val = '${e.distanceKm ?? ''} ${e.minutes ?? ''} ${e.kcal}'.trim();
      buf.writeln(
        '${_csvCell(e.day)},activity,${_csvCell(e.label)},${_csvCell(val)},${e.confirmed ? 1 : 0}',
      );
    }
    for (final e in sleeps) {
      if (!e.isComplete) continue;
      buf.writeln('${_csvCell(e.day)},sleep,,${e.durationHours},1');
    }
    for (final e in weights) {
      buf.writeln('${_csvCell(e.day)},weight,,${e.kg},1');
    }
    for (final e in steps) {
      buf.writeln('${_csvCell(e.day)},steps,,${e.steps},1');
    }
    return buf.toString();
  }

  List<JournalEntry> entriesOn(String day) =>
      journal.where((e) => e.day == day).toList();

  int? stepsOn(String day) {
    final matches = steps.where((e) => e.day == day);
    if (matches.isEmpty) return null;
    return matches.fold<int>(0, (a, s) => a + s.steps);
  }

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
    WeightEntry? best;
    for (final w in weights) {
      if (best == null || w.day.compareTo(best.day) >= 0) best = w;
    }
    return best;
  }

  /// Last logged mass on or before [day], in kilograms.
  double? weightOnOrBefore(String day) {
    WeightEntry? best;
    for (final w in weights) {
      if (w.day.compareTo(day) <= 0) {
        if (best == null || w.day.compareTo(best.day) >= 0) best = w;
      }
    }
    return best?.kg;
  }
}
