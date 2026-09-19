import '../db/records.dart';
import '../db/store.dart';
import '../fitness/progress.dart';

/// Style variant for the synthesized daily digest sentence.
enum DigestVariant {
  /// Dense, direct instrument synthesis (default).
  concise,

  /// Narrative instrument observation synthesizing the day's pillars.
  narrative,

  /// Structured metric-forward ledger synthesis.
  metric,
}

enum _SleepSufficiency { restful, unrested, short, neutral }

enum _TrainingType { rest, sets, session, distance, movement, none }

enum _EnergyType { surplus, deficit, balanced, intakeOnly, burnOnly, none }

/// One instrument sentence for a day. Facts only — never advice, never
/// prescriptions, never causal or medical claims, and never second person.
/// Empty (null) when the record cannot support a sentence.
///
/// Synthesizes intake vs expenditure, training presence, and sleep sufficiency.
/// Guaranteed to be ≤ 140 characters.
String? composeDayDigest(
  AppStore store,
  String day,
  DaySummary s, {
  DigestVariant variant = DigestVariant.concise,
}) {
  // 1. Sleep Sufficiency
  final hasSleep = s.sleepHours != null && s.sleepHours! > 0;
  final dur = hasSleep ? _dur(s.sleepHours!) : '';
  SleepEntry? night;
  for (final e in store.sleeps) {
    if (e.day == day) {
      night = e;
      break;
    }
  }
  final q = night?.quality ?? s.sleepScore;
  _SleepSufficiency sleepSufficiency = _SleepSufficiency.neutral;
  if (hasSleep) {
    if (q != null) {
      if (q >= 0.75) {
        sleepSufficiency = _SleepSufficiency.restful;
      } else if (q < 0.5) {
        sleepSufficiency = _SleepSufficiency.unrested;
      }
    } else {
      if (s.sleepHours! >= 8.0) {
        sleepSufficiency = _SleepSufficiency.restful;
      } else if (s.sleepHours! < 6.0) {
        sleepSufficiency = _SleepSufficiency.short;
      }
    }
  }

  // 2. Training Presence
  final sessions = sessionsOn(store, day);
  final setsCount = s.sets ?? 0;
  final distKm = s.distanceKm ?? 0.0;
  final moveMin = s.moveMinutes ?? 0.0;
  final isRest =
      s.strain == 0 &&
      sessions.isEmpty &&
      setsCount == 0 &&
      distKm == 0 &&
      moveMin == 0;

  _TrainingType trainType = _TrainingType.none;
  if (isRest) {
    trainType = _TrainingType.rest;
  } else if (setsCount > 0) {
    trainType = _TrainingType.sets;
  } else if (sessions.isNotEmpty) {
    trainType = _TrainingType.session;
  } else if (distKm > 0) {
    trainType = _TrainingType.distance;
  } else if (moveMin > 0) {
    trainType = _TrainingType.movement;
  }
  final hasTrain = trainType != _TrainingType.none;

  // 3. Energy: Intake vs Expenditure
  final intake = s.intakeKcal?.round();
  final burn = s.expenditureKcal?.round();
  final delta =
      s.energyKcal?.round() ??
      (intake != null && burn != null ? intake - burn : null);

  _EnergyType energyType = _EnergyType.none;
  if (delta != null) {
    if (delta > 50) {
      energyType = _EnergyType.surplus;
    } else if (delta < -50) {
      energyType = _EnergyType.deficit;
    } else {
      energyType = _EnergyType.balanced;
    }
  } else if (intake != null) {
    energyType = _EnergyType.intakeOnly;
  } else if (burn != null) {
    energyType = _EnergyType.burnOnly;
  }
  final hasEnergy = energyType != _EnergyType.none;

  if (!hasSleep && !hasTrain && !hasEnergy) return null;

  switch (variant) {
    case DigestVariant.concise:
      return _composeConcise(
        hasSleep: hasSleep,
        dur: dur,
        sleepSufficiency: sleepSufficiency,
        trainType: trainType,
        setsCount: setsCount,
        sessions: sessions,
        distKm: distKm,
        moveMin: moveMin,
        energyType: energyType,
        delta: delta,
        intake: intake,
        burn: burn,
      );
    case DigestVariant.narrative:
      return _composeNarrative(
        hasSleep: hasSleep,
        dur: dur,
        sleepSufficiency: sleepSufficiency,
        trainType: trainType,
        setsCount: setsCount,
        sessions: sessions,
        distKm: distKm,
        moveMin: moveMin,
        energyType: energyType,
        delta: delta,
        intake: intake,
        burn: burn,
      );
    case DigestVariant.metric:
      return _composeMetric(
        hasSleep: hasSleep,
        dur: dur,
        sleepSufficiency: sleepSufficiency,
        trainType: trainType,
        setsCount: setsCount,
        sessions: sessions,
        distKm: distKm,
        moveMin: moveMin,
        energyType: energyType,
        delta: delta,
        intake: intake,
        burn: burn,
      );
  }
}

String? _composeConcise({
  required bool hasSleep,
  required String dur,
  required _SleepSufficiency sleepSufficiency,
  required _TrainingType trainType,
  required int setsCount,
  required List<SessionFigure> sessions,
  required double distKm,
  required double moveMin,
  required _EnergyType energyType,
  required int? delta,
  required int? intake,
  required int? burn,
}) {
  final sleep = _conciseSleep(dur, sleepSufficiency);
  final train = _conciseTrain(trainType, setsCount, sessions, distKm, moveMin);
  final energy = _conciseEnergy(energyType, delta, intake, burn);

  final hasTrain = trainType != _TrainingType.none;
  final hasEnergy = energyType != _EnergyType.none;

  if (hasSleep && hasTrain && hasEnergy) {
    if (trainType == _TrainingType.rest) {
      if (energyType == _EnergyType.intakeOnly ||
          energyType == _EnergyType.burnOnly) {
        return _finalize('$sleep across a rest day. $energy.');
      }
      return _finalize('$sleep across a rest day, closing at $energy.');
    }
    return _finalize('$sleep, $train, and $energy.');
  }
  if (hasSleep && hasTrain) {
    if (trainType == _TrainingType.rest) {
      return _finalize('$sleep followed by a rest day.');
    }
    return _finalize('$sleep paired with $train.');
  }
  if (hasSleep && hasEnergy) {
    return _finalize('$sleep and $energy.');
  }
  if (hasTrain && hasEnergy) {
    if (trainType == _TrainingType.rest) {
      if (energyType == _EnergyType.intakeOnly ||
          energyType == _EnergyType.burnOnly) {
        return _finalize('Rest. $energy.');
      }
      return _finalize('A rest day with $energy.');
    }
    return _finalize('${_cap(train)} with $energy.');
  }
  if (hasSleep) {
    return _finalize('${_cap(sleep)} recorded.');
  }
  if (hasTrain) {
    if (trainType == _TrainingType.rest) {
      return 'Rest.';
    }
    return _finalize('${_cap(train)} logged.');
  }
  if (hasEnergy) {
    return _finalize('${_cap(energy)} recorded.');
  }
  return null;
}

String? _composeNarrative({
  required bool hasSleep,
  required String dur,
  required _SleepSufficiency sleepSufficiency,
  required _TrainingType trainType,
  required int setsCount,
  required List<SessionFigure> sessions,
  required double distKm,
  required double moveMin,
  required _EnergyType energyType,
  required int? delta,
  required int? intake,
  required int? burn,
}) {
  final sleep = _narrativeSleep(dur, sleepSufficiency);
  final train = _narrativeTrain(
    trainType,
    setsCount,
    sessions,
    distKm,
    moveMin,
  );
  final energy = _narrativeEnergy(energyType, delta, intake, burn);

  final hasTrain = trainType != _TrainingType.none;
  final hasEnergy = energyType != _EnergyType.none;

  if (hasSleep && hasTrain && hasEnergy) {
    if (trainType == _TrainingType.rest) {
      return _finalize(
        'A rest day following $sleep closed with $energy.',
      );
    }
    return _finalize(
      '${_cap(energy)} accompanied $train following $sleep.',
    );
  }
  if (hasSleep && hasTrain) {
    if (trainType == _TrainingType.rest) {
      return _finalize(
        'Following $sleep, the day was kept as a rest day.',
      );
    }
    return _finalize('Following $sleep, training logged $train.');
  }
  if (hasSleep && hasEnergy) {
    return _finalize(
      'The day concluded with $energy following $sleep.',
    );
  }
  if (hasTrain && hasEnergy) {
    if (trainType == _TrainingType.rest) {
      return _finalize('A rest day concluded with $energy.');
    }
    return _finalize('${_cap(train)} concluded the day with $energy.');
  }
  if (hasSleep) {
    return _finalize('The day recorded $sleep.');
  }
  if (hasTrain) {
    if (trainType == _TrainingType.rest) {
      return _finalize('The day was logged as a rest day.');
    }
    return _finalize('The day logged $train.');
  }
  if (hasEnergy) {
    return _finalize('The day closed with $energy.');
  }
  return null;
}

String? _composeMetric({
  required bool hasSleep,
  required String dur,
  required _SleepSufficiency sleepSufficiency,
  required _TrainingType trainType,
  required int setsCount,
  required List<SessionFigure> sessions,
  required double distKm,
  required double moveMin,
  required _EnergyType energyType,
  required int? delta,
  required int? intake,
  required int? burn,
}) {
  final parts = <String>[];
  if (hasSleep) {
    parts.add(_metricSleep(dur, sleepSufficiency));
  }
  if (trainType != _TrainingType.none) {
    parts.add(_metricTrain(trainType, setsCount, sessions, distKm, moveMin));
  }
  if (energyType != _EnergyType.none) {
    parts.add(_metricEnergy(energyType, delta, intake, burn));
  }
  if (parts.isEmpty) return null;
  return _finalize('${parts.join(' · ')}.');
}

String _conciseSleep(String dur, _SleepSufficiency s) {
  switch (s) {
    case _SleepSufficiency.restful:
      return '$dur restful sleep';
    case _SleepSufficiency.unrested:
      return '$dur sleep, poorly';
    case _SleepSufficiency.short:
      return '$dur short sleep';
    case _SleepSufficiency.neutral:
      return '$dur sleep';
  }
}

String _narrativeSleep(String dur, _SleepSufficiency s) {
  switch (s) {
    case _SleepSufficiency.restful:
      return '$dur of restful sleep';
    case _SleepSufficiency.unrested:
      return '$dur of unrested sleep';
    case _SleepSufficiency.short:
      return '$dur of short sleep';
    case _SleepSufficiency.neutral:
      return '$dur of sleep';
  }
}

String _metricSleep(String dur, _SleepSufficiency s) {
  switch (s) {
    case _SleepSufficiency.restful:
      return 'Sleep $dur (restful)';
    case _SleepSufficiency.unrested:
      return 'Sleep $dur (unrested)';
    case _SleepSufficiency.short:
      return 'Sleep $dur (short)';
    case _SleepSufficiency.neutral:
      return 'Sleep $dur';
  }
}

String _conciseTrain(
  _TrainingType type,
  int sets,
  List<SessionFigure> sessions,
  double distKm,
  double moveMin,
) {
  switch (type) {
    case _TrainingType.rest:
      return 'rest day';
    case _TrainingType.sets:
      if (sessions.isNotEmpty) {
        final lbl = _shortLabel(sessions.first.label);
        return '$sets sets and $lbl';
      }
      return '$sets sets lifted';
    case _TrainingType.session:
      final sess = sessions.first;
      final lbl = _shortLabel(sess.label);
      if (sess.value.isNotEmpty) return '$lbl ${sess.value}'.trim();
      return lbl;
    case _TrainingType.distance:
      return '${distKm.toStringAsFixed(1)} km logged';
    case _TrainingType.movement:
      return '${moveMin.round()}m movement';
    case _TrainingType.none:
      return '';
  }
}

String _narrativeTrain(
  _TrainingType type,
  int sets,
  List<SessionFigure> sessions,
  double distKm,
  double moveMin,
) {
  switch (type) {
    case _TrainingType.rest:
      return 'a rest day';
    case _TrainingType.sets:
      if (sessions.isNotEmpty) {
        final lbl = _shortLabel(sessions.first.label);
        return '$sets sets lifted alongside $lbl';
      }
      return '$sets sets lifted';
    case _TrainingType.session:
      final sess = sessions.first;
      final lbl = _shortLabel(sess.label);
      if (sess.value.isNotEmpty) return '$lbl ${sess.value}'.trim();
      return lbl;
    case _TrainingType.distance:
      return '${distKm.toStringAsFixed(1)} km logged';
    case _TrainingType.movement:
      return '${moveMin.round()}m of movement';
    case _TrainingType.none:
      return '';
  }
}

String _metricTrain(
  _TrainingType type,
  int sets,
  List<SessionFigure> sessions,
  double distKm,
  double moveMin,
) {
  switch (type) {
    case _TrainingType.rest:
      return 'Rest day';
    case _TrainingType.sets:
      if (sessions.isNotEmpty) {
        final lbl = _shortLabel(sessions.first.label);
        return '$sets sets · $lbl';
      }
      return '$sets sets';
    case _TrainingType.session:
      final sess = sessions.first;
      final lbl = _shortLabel(sess.label);
      if (sess.value.isNotEmpty) return '$lbl ${sess.value}'.trim();
      return lbl;
    case _TrainingType.distance:
      return '${distKm.toStringAsFixed(1)} km';
    case _TrainingType.movement:
      return '${moveMin.round()}m movement';
    case _TrainingType.none:
      return '';
  }
}

String _conciseEnergy(
  _EnergyType type,
  int? delta,
  int? intake,
  int? burn,
) {
  switch (type) {
    case _EnergyType.surplus:
      return 'a $delta kcal surplus';
    case _EnergyType.deficit:
      return 'a ${delta!.abs()} kcal deficit';
    case _EnergyType.balanced:
      return 'balanced energy';
    case _EnergyType.intakeOnly:
      return 'Intake $intake kcal';
    case _EnergyType.burnOnly:
      return 'Burn $burn kcal';
    case _EnergyType.none:
      return '';
  }
}

String _narrativeEnergy(
  _EnergyType type,
  int? delta,
  int? intake,
  int? burn,
) {
  switch (type) {
    case _EnergyType.surplus:
      return 'a $delta kcal surplus';
    case _EnergyType.deficit:
      return 'a ${delta!.abs()} kcal deficit';
    case _EnergyType.balanced:
      return 'balanced energy';
    case _EnergyType.intakeOnly:
      return 'an intake of $intake kcal';
    case _EnergyType.burnOnly:
      return 'an expenditure of $burn kcal';
    case _EnergyType.none:
      return '';
  }
}

String _metricEnergy(
  _EnergyType type,
  int? delta,
  int? intake,
  int? burn,
) {
  switch (type) {
    case _EnergyType.surplus:
      if (intake != null && burn != null) {
        return 'Energy +$delta kcal ($intake in / $burn out)';
      }
      return 'Energy +$delta kcal (surplus)';
    case _EnergyType.deficit:
      if (intake != null && burn != null) {
        return 'Energy −${delta!.abs()} kcal ($intake in / $burn out)';
      }
      return 'Energy −${delta!.abs()} kcal (deficit)';
    case _EnergyType.balanced:
      if (intake != null && burn != null) {
        return 'Energy balance ($intake in / $burn out)';
      }
      return 'Energy balanced';
    case _EnergyType.intakeOnly:
      return 'Intake $intake kcal';
    case _EnergyType.burnOnly:
      return 'Burn $burn kcal';
    case _EnergyType.none:
      return '';
  }
}

String _shortLabel(String label) {
  if (label.length <= 20) return label;
  return '${label.substring(0, 19)}…';
}

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _dur(double h) {
  final m = (h.abs() * 60).round();
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

String _finalize(String sentence) {
  if (sentence.length <= 140) return sentence;
  final trimmed = sentence.substring(0, 139).trimRight();
  final lastSpace = trimmed.lastIndexOf(' ');
  if (lastSpace > 80) {
    return '${trimmed.substring(0, lastSpace).trimRight()}.';
  }
  return '$trimmed.';
}
