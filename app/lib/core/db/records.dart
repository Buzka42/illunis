import 'dart:math';

import 'package:flutter/foundation.dart';

String newId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
      '${r.nextInt(1 << 32).toRadixString(16)}';
}

/// 16 random bytes, hex. Header-only identity for the AI meter.
String newInstallId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String dayKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime dayKeyDate(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

@immutable
class Profile {
  const Profile({
    this.units = 'metric',
    this.homePlace,
    this.latitudeDeg = 52.23,
    this.longitudeDeg = 21.01,
    this.aiConsentAt,
    this.ageAtLeast16 = false,
    required this.installId,
  });

  final String units;
  final String? homePlace;
  final double latitudeDeg;
  final double longitudeDeg;
  final DateTime? aiConsentAt;
  final bool ageAtLeast16;
  final String installId;

  bool get hasAiConsent => aiConsentAt != null;

  Profile copyWith({
    String? units,
    Object? homePlace = _u,
    double? latitudeDeg,
    double? longitudeDeg,
    Object? aiConsentAt = _u,
    bool? ageAtLeast16,
    String? installId,
  }) => Profile(
    units: units ?? this.units,
    homePlace: homePlace == _u ? this.homePlace : homePlace as String?,
    latitudeDeg: latitudeDeg ?? this.latitudeDeg,
    longitudeDeg: longitudeDeg ?? this.longitudeDeg,
    aiConsentAt: aiConsentAt == _u
        ? this.aiConsentAt
        : aiConsentAt as DateTime?,
    ageAtLeast16: ageAtLeast16 ?? this.ageAtLeast16,
    installId: installId ?? this.installId,
  );

  Map<String, Object?> toJson() => {
    'units': units,
    'homePlace': homePlace,
    'latitudeDeg': latitudeDeg,
    'longitudeDeg': longitudeDeg,
    'aiConsentAt': aiConsentAt?.toIso8601String(),
    'ageAtLeast16': ageAtLeast16,
    'installId': installId,
  };

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
    units: j['units'] as String? ?? 'metric',
    homePlace: j['homePlace'] as String?,
    latitudeDeg: (j['latitudeDeg'] as num?)?.toDouble() ?? 52.23,
    longitudeDeg: (j['longitudeDeg'] as num?)?.toDouble() ?? 21.01,
    aiConsentAt: j['aiConsentAt'] == null
        ? null
        : DateTime.tryParse(j['aiConsentAt'] as String),
    ageAtLeast16: j['ageAtLeast16'] as bool? ?? false,
    installId: j['installId'] as String? ?? newInstallId(),
  );
}

@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.at,
    required this.text,
    this.excludedFromAi = false,
    this.status = 'logged',
  });

  final String id;
  final DateTime at;
  final String text;
  final bool excludedFromAi;
  final String status;

  String get day => dayKey(at);

  Map<String, Object?> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'text': text,
    'excludedFromAi': excludedFromAi,
    'status': status,
  };

  factory JournalEntry.fromJson(Map<String, Object?> j) => JournalEntry(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    text: j['text'] as String,
    excludedFromAi: j['excludedFromAi'] as bool? ?? false,
    status: j['status'] as String? ?? 'logged',
  );

  JournalEntry copyWith({bool? excludedFromAi}) => JournalEntry(
    id: id,
    at: at,
    text: text,
    excludedFromAi: excludedFromAi ?? this.excludedFromAi,
    status: status,
  );
}

@immutable
class StrengthSet {
  const StrengthSet({
    required this.id,
    required this.journalEntryId,
    required this.day,
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    this.sets = 1,
    this.epley1rm,
    this.brzycki1rm,
    this.rpe,
  });

  final String id;
  final String journalEntryId;
  final String day;
  final String exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final int sets;
  final double? epley1rm;
  final double? brzycki1rm;
  final double? rpe;

  int get totalReps => reps * sets;
  double get volumeKg => weightKg * totalReps;

  Map<String, Object?> toJson() => {
    'id': id,
    'journalEntryId': journalEntryId,
    'day': day,
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'weightKg': weightKg,
    'reps': reps,
    'sets': sets,
    'epley1rm': epley1rm,
    'brzycki1rm': brzycki1rm,
    'rpe': rpe,
  };

  factory StrengthSet.fromJson(Map<String, Object?> j) => StrengthSet(
    id: j['id'] as String,
    journalEntryId: j['journalEntryId'] as String,
    day: j['day'] as String,
    exerciseId: j['exerciseId'] as String,
    exerciseName: j['exerciseName'] as String,
    weightKg: (j['weightKg'] as num).toDouble(),
    reps: (j['reps'] as num).toInt(),
    sets: (j['sets'] as num?)?.toInt() ?? 1,
    epley1rm: (j['epley1rm'] as num?)?.toDouble(),
    brzycki1rm: (j['brzycki1rm'] as num?)?.toDouble(),
    rpe: (j['rpe'] as num?)?.toDouble(),
  );
}

@immutable
class NutritionEntry {
  const NutritionEntry({
    required this.id,
    required this.journalEntryId,
    required this.day,
    required this.label,
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.confirmed = false,
    this.source = 'parsed',
  });

  final String id;
  final String journalEntryId;
  final String day;
  final String label;
  final double kcal;
  final double? proteinG, carbsG, fatG;
  final bool confirmed;
  final String source;

  NutritionEntry copyWith({bool? confirmed}) => NutritionEntry(
    id: id,
    journalEntryId: journalEntryId,
    day: day,
    label: label,
    kcal: kcal,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
    confirmed: confirmed ?? this.confirmed,
    source: source,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'journalEntryId': journalEntryId,
    'day': day,
    'label': label,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'confirmed': confirmed,
    'source': source,
  };

  factory NutritionEntry.fromJson(Map<String, Object?> j) => NutritionEntry(
    id: j['id'] as String,
    journalEntryId: j['journalEntryId'] as String,
    day: j['day'] as String,
    label: j['label'] as String,
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['proteinG'] as num?)?.toDouble(),
    carbsG: (j['carbsG'] as num?)?.toDouble(),
    fatG: (j['fatG'] as num?)?.toDouble(),
    confirmed: j['confirmed'] as bool? ?? false,
    source: j['source'] as String? ?? 'parsed',
  );
}

@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.journalEntryId,
    required this.day,
    required this.label,
    required this.kcal,
    this.disciplineId = 'other',
    this.minutes,
    this.distanceKm,
    this.paceSecPerKm,
    this.rpe,
    this.hrAvg,
    this.effort,
    this.confirmed = false,
    this.source = 'parsed',
  });

  final String id;
  final String journalEntryId;
  final String day;
  final String label;
  final String disciplineId;
  final double kcal;
  final double? minutes;
  final double? distanceKm;
  final double? paceSecPerKm;
  final double? rpe;
  final double? hrAvg;

  /// easy | steady | tempo | intervals | race | long — when the line said so.
  final String? effort;
  final bool confirmed;
  final String source;

  ActivityEntry copyWith({bool? confirmed}) => ActivityEntry(
    id: id,
    journalEntryId: journalEntryId,
    day: day,
    label: label,
    disciplineId: disciplineId,
    kcal: kcal,
    minutes: minutes,
    distanceKm: distanceKm,
    paceSecPerKm: paceSecPerKm,
    rpe: rpe,
    hrAvg: hrAvg,
    effort: effort,
    confirmed: confirmed ?? this.confirmed,
    source: source,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'journalEntryId': journalEntryId,
    'day': day,
    'label': label,
    'disciplineId': disciplineId,
    'kcal': kcal,
    'minutes': minutes,
    'distanceKm': distanceKm,
    'paceSecPerKm': paceSecPerKm,
    'rpe': rpe,
    'hrAvg': hrAvg,
    'effort': effort,
    'confirmed': confirmed,
    'source': source,
  };

  factory ActivityEntry.fromJson(Map<String, Object?> j) => ActivityEntry(
    id: j['id'] as String,
    journalEntryId: j['journalEntryId'] as String,
    day: j['day'] as String,
    label: j['label'] as String,
    disciplineId: j['disciplineId'] as String? ?? 'other',
    kcal: (j['kcal'] as num).toDouble(),
    minutes: (j['minutes'] as num?)?.toDouble(),
    distanceKm: (j['distanceKm'] as num?)?.toDouble(),
    paceSecPerKm: (j['paceSecPerKm'] as num?)?.toDouble(),
    rpe: (j['rpe'] as num?)?.toDouble(),
    hrAvg: (j['hrAvg'] as num?)?.toDouble(),
    effort: j['effort'] as String?,
    confirmed: j['confirmed'] as bool? ?? false,
    source: j['source'] as String? ?? 'parsed',
  );
}

@immutable
class SleepEntry {
  const SleepEntry({
    required this.id,
    required this.journalEntryId,
    required this.day,
    required this.startHours,
    required this.endHours,
    this.quality,
  });

  final String id;
  final String journalEntryId;

  /// The morning's day key (the day you woke).
  final String day;
  final double startHours;
  final double endHours;

  /// How the night felt, `0..1`, when they said so. Null means duration only.
  final double? quality;

  double get durationHours => endHours - startHours;

  /// A bedtime without a wake is stored so the morning can finish it.
  /// It is not a night — duration stays out of totals until then.
  bool get isComplete => durationHours >= 0.08;

  Map<String, Object?> toJson() => {
    'id': id,
    'journalEntryId': journalEntryId,
    'day': day,
    'startHours': startHours,
    'endHours': endHours,
    if (quality != null) 'quality': quality,
  };

  factory SleepEntry.fromJson(Map<String, Object?> j) => SleepEntry(
    id: j['id'] as String,
    journalEntryId: j['journalEntryId'] as String,
    day: j['day'] as String,
    startHours: (j['startHours'] as num).toDouble(),
    endHours: (j['endHours'] as num).toDouble(),
    quality: (j['quality'] as num?)?.toDouble(),
  );

  SleepEntry copyWith({
    String? day,
    double? startHours,
    double? endHours,
    double? quality,
  }) => SleepEntry(
    id: id,
    journalEntryId: journalEntryId,
    day: day ?? this.day,
    startHours: startHours ?? this.startHours,
    endHours: endHours ?? this.endHours,
    quality: quality ?? this.quality,
  );
}

@immutable
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.journalEntryId,
    required this.day,
    required this.kg,
  });

  final String id;
  final String journalEntryId;
  final String day;
  final double kg;

  Map<String, Object?> toJson() => {
    'id': id,
    'journalEntryId': journalEntryId,
    'day': day,
    'kg': kg,
  };

  factory WeightEntry.fromJson(Map<String, Object?> j) => WeightEntry(
    id: j['id'] as String,
    journalEntryId: j['journalEntryId'] as String,
    day: j['day'] as String,
    kg: (j['kg'] as num).toDouble(),
  );
}

@immutable
class DaySummary {
  const DaySummary({
    required this.day,
    this.sleepHours,
    this.sleepScore,
    this.recovery,
    this.strain,
    this.intakeKcal,
    this.expenditureKcal,
    this.energyBalance,
    this.sets,
    this.volumeKg,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.energyKcal,
    this.digest,
    this.digestSource,
    this.best1rmKg,
    this.moveMinutes,
    this.distanceKm,
    this.runSpeedKmh,
  });

  final String day;
  final double? sleepHours;
  final double? sleepScore;
  final double? recovery;
  final double? strain;
  final double? intakeKcal;
  final double? expenditureKcal;
  final double? energyBalance;
  final int? sets;
  final double? volumeKg;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  /// 7-day mean of intake − expenditure, kcal. Null when energyBalance is.
  final double? energyKcal;

  /// Optional one-sentence day digest. Local figures, or the worker.
  final String? digest;

  /// `local` or `ai`. AI is kept across rollup refreshes.
  final String? digestSource;

  /// Best Epley 1RM logged this day, if any. Feeds the surplus ↔ strength pair.
  final double? best1rmKg;

  /// Minutes of logged movement (every discipline).
  final double? moveMinutes;

  /// Endurance distance, kilometres.
  final double? distanceKm;

  /// Best run that day as km/h. Higher is faster. Null when no timed run.
  final double? runSpeedKmh;

  DaySummary copyWith({String? digest, String? digestSource}) => DaySummary(
    day: day,
    sleepHours: sleepHours,
    sleepScore: sleepScore,
    recovery: recovery,
    strain: strain,
    intakeKcal: intakeKcal,
    expenditureKcal: expenditureKcal,
    energyBalance: energyBalance,
    sets: sets,
    volumeKg: volumeKg,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
    energyKcal: energyKcal,
    digest: digest ?? this.digest,
    digestSource: digestSource ?? this.digestSource,
    best1rmKg: best1rmKg,
    moveMinutes: moveMinutes,
    distanceKm: distanceKm,
    runSpeedKmh: runSpeedKmh,
  );

  Map<String, Object?> toJson() => {
    'day': day,
    'sleepHours': sleepHours,
    'sleepScore': sleepScore,
    'recovery': recovery,
    'strain': strain,
    'intakeKcal': intakeKcal,
    'expenditureKcal': expenditureKcal,
    'energyBalance': energyBalance,
    'sets': sets,
    'volumeKg': volumeKg,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'energyKcal': energyKcal,
    'digest': digest,
    'digestSource': digestSource,
    'best1rmKg': best1rmKg,
    'moveMinutes': moveMinutes,
    'distanceKm': distanceKm,
    'runSpeedKmh': runSpeedKmh,
  };

  factory DaySummary.fromJson(Map<String, Object?> j) => DaySummary(
    day: j['day'] as String,
    sleepHours: (j['sleepHours'] as num?)?.toDouble(),
    sleepScore: (j['sleepScore'] as num?)?.toDouble(),
    recovery: (j['recovery'] as num?)?.toDouble(),
    strain: (j['strain'] as num?)?.toDouble(),
    intakeKcal: (j['intakeKcal'] as num?)?.toDouble(),
    expenditureKcal: (j['expenditureKcal'] as num?)?.toDouble(),
    energyBalance: (j['energyBalance'] as num?)?.toDouble(),
    sets: (j['sets'] as num?)?.toInt(),
    volumeKg: (j['volumeKg'] as num?)?.toDouble(),
    proteinG: (j['proteinG'] as num?)?.toDouble(),
    carbsG: (j['carbsG'] as num?)?.toDouble(),
    fatG: (j['fatG'] as num?)?.toDouble(),
    energyKcal: (j['energyKcal'] as num?)?.toDouble(),
    digest: j['digest'] as String?,
    digestSource: j['digestSource'] as String?,
    best1rmKg: (j['best1rmKg'] as num?)?.toDouble(),
    moveMinutes: (j['moveMinutes'] as num?)?.toDouble(),
    distanceKm: (j['distanceKm'] as num?)?.toDouble(),
    runSpeedKmh: (j['runSpeedKmh'] as num?)?.toDouble(),
  );
}

const _u = Object();
