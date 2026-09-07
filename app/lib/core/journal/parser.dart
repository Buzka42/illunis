import '../db/records.dart';
import '../fitness/session.dart';
import '../i18n/fold.dart';
import '../nutrition/foods.dart';
import '../strength/canon.dart';
import '../strength/one_rm.dart';
import '../units/mass.dart';

/// What the local parser pulled out of one journal page. Empty is fine —
/// the prose is still the record.
class ParsedJournal {
  const ParsedJournal({
    this.sets = const [],
    this.nutrition = const [],
    this.activities = const [],
    this.sleeps = const [],
    this.weights = const [],
  });

  final List<StrengthSet> sets;
  final List<NutritionEntry> nutrition;
  final List<ActivityEntry> activities;
  final List<SleepEntry> sleeps;
  final List<WeightEntry> weights;

  bool get isEmpty =>
      sets.isEmpty &&
      nutrition.isEmpty &&
      activities.isEmpty &&
      sleeps.isEmpty &&
      weights.isEmpty;
}

final _setX = RegExp(
  r'([A-Za-z][A-Za-z0-9 +\-]*?)\s+(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds|#)?\s*(?:[x×]|times)\s*(\d+)(?:\s*(?:[x×]|times)\s*(\d+))?(?:\s*(?:@|rpe)\s*(\d+(?:\.\d+)?))?',
  caseSensitive: false,
);
final _setKgReps = RegExp(
  r'([A-Za-z][A-Za-z0-9 +\-]*?)\s+(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds)\s+(\d+)\s*reps?(?:\s*(?:[x×]|times)\s*(\d+))?(?:\s*(?:@|rpe)\s*(\d+(?:\.\d+)?))?',
  caseSensitive: false,
);
final _proseSet = RegExp(
  r'([A-Za-z][A-Za-z0-9 +\-]*?)\s+(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds)?\s+(?:for\s+)?(\d+)(?:\s*reps?)?(?:\s*(?:[x×]|times)\s*(\d+))?',
  caseSensitive: false,
);
final _setNxN = RegExp(
  r'^(\d+)\s*(?:[x×]|times)\s*(\d+)\s+([A-Za-z][A-Za-z0-9 +\-]*?)(?:\s+(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds|#)?)?(?:\s*(?:@|rpe)\s*(\d+(?:\.\d+)?))?$',
  caseSensitive: false,
);
final _setsOf = RegExp(
  r'^(\d+)\s+sets?\s+of\s+(\d+)\s+([A-Za-z][A-Za-z0-9 +\-]*?)(?:\s+(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds|#)?)?(?:\s*(?:@|rpe)\s*(\d+(?:\.\d+)?))?$',
  caseSensitive: false,
);
final _bwCount = RegExp(
  r'^(\d{1,3})\s+([A-Za-z][A-Za-z0-9 +\-]+)$',
  caseSensitive: false,
);
final _nap = RegExp(
  r'\b(?:napped|nap)\s+(?:for\s+)?(\d+(?:\.\d+)?)\s*(min|mins|minutes|h|hr|hours?)?\b',
  caseSensitive: false,
);
final _sleepVerb = r'(?:slept?|spalem|spalam)';
final _sleepClock = RegExp(
  '$_sleepVerb\\s+(\\d{1,2})[:.](\\d{2})\\s*[-–to]+\\s*(\\d{1,2})[:.](\\d{2})',
  caseSensitive: false,
);
final _sleepFrom = RegExp(
  '$_sleepVerb\\s+(?:from\\s+)?(\\d{1,2})(?:[:.](\\d{2}))?\\s*(am|pm)?\\s*(?:to|until|-)\\s*(\\d{1,2})(?:[:.](\\d{2}))?\\s*(am|pm)?',
  caseSensitive: false,
);
final _sleepHm = RegExp(
  '$_sleepVerb\\s+(?:for\\s+)?(\\d+)\\s*(?:h(?:ours?)?|godzin(?:y|e)?)\\s*(?:and\\s*)?(\\d+)\\s*(?:m(?:in(?:utes?)?)?|minut(?:y|e)?)',
  caseSensitive: false,
);
final _sleepH = RegExp(
  '$_sleepVerb\\s+(?:for\\s+)?(\\d+(?:\\.\\d+)?)\\s*(?:h(?:ours?)?|godzin(?:y|e)?)\\b',
  caseSensitive: false,
);
final _sleepMin = RegExp(
  '$_sleepVerb\\s+(?:for\\s+)?(\\d+)\\s*(?:min|mins|minutes|minut(?:y|e)?)\\b',
  caseSensitive: false,
);
final _weight = RegExp(
  r"\b(?:weigh(?:ed(?:\s+in)?(?:\s+at)?)?|weight|waze|i(?:['’]m|\s+am))\s+(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds)?",
  caseSensitive: false,
);
final _bareMass = RegExp(
  r'^(\d+(?:\.\d+)?)\s*(kg|kgs|kilos?|lb|lbs|pounds)\s*$',
  caseSensitive: false,
);
final _kcal = RegExp(r'(\d+(?:\.\d+)?)\s*k(?:cal|c)\b', caseSensitive: false);
final _protein = RegExp(
  r'(\d+(?:\.\d+)?)\s*g(?:rams?)?\s+protein|protein\s+(\d+(?:\.\d+)?)\s*g',
  caseSensitive: false,
);
final _ate = RegExp(
  r'\b(?:ate|had|eaten|eating|drank|drink|drunk|grabbed|ordered|snacked(?:\s+on)?|zjadlem|zjadlam|jadlem|jadlam|wypilem|wypilam)\s+(.+)',
  caseSensitive: false,
);
final _foodSplit = RegExp(
  r'\s+and\s+|,\s+|\s+with\s+|\s+z\s+|\s+i\s+',
  caseSensitive: false,
);
final _sleepQualityBad = RegExp(
  r"\b(slept?\s+(?:\S+\s+){0,4}(poorly|badly|terrible|awful|rough)|poor\s+sleep|bad\s+sleep|restless(?:ly)?|insomnia|woke\s+(a\s+lot|often)|broken\s+sleep|tossed|could(?:n['’]?t|\s+not)\s+sleep)\b",
  caseSensitive: false,
);
final _sleepQualityGood = RegExp(
  r'\b(slept?\s+(?:\S+\s+){0,4}(well|deep(?:ly)?|great|solid|through)|good\s+sleep|deep\s+sleep|slept\s+like\s+a\s+rock)\b',
  caseSensitive: false,
);

final _bed = RegExp(
  r'(?:went to (?:bed|sleep)|fell asleep|headed to bed|in bed|bedtime|lights out|poszedl[ae]m spac|poszlam spac)\s+(?:(?:at|around|about|o)\s+)?(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
  caseSensitive: false,
);
final _woke = RegExp(
  r'(?:woke(?:\s+up)?|got up|(?:was\s+)?\bup\b|wstal[ae]m|obudzil[ae]m(?:\s+sie)?)\s+(?:(?:at|around|about|o)\s+)?(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
  caseSensitive: false,
);
final _sleptUntil = RegExp(
  r'\b(?:slept?|spalem|spalam)\s+(?:until|till)\s+(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?',
  caseSensitive: false,
);

const _bodyweightIds = {
  'pull-up',
  'dip',
  'push-up',
  'plank',
  'hanging-leg-raise',
  'sit-up',
  'ab-wheel',
};

ParsedJournal parseJournal(
  JournalEntry entry, {
  double bodyKg = 75,
  String units = 'metric',
}) {
  final sets = <StrengthSet>[];
  final nutrition = <NutritionEntry>[];
  final activities = <ActivityEntry>[];
  final sleeps = <SleepEntry>[];
  final weights = <WeightEntry>[];

  final chunks = foldDecimal(entry.text)
      .split(RegExp(r'[\n;,]+|\bthen\b', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final quality = sleepQualityOf(entry.text);

  for (final raw in chunks) {
    final chunk = _stripLeadIn(foldSpoken(raw));
    if (chunk.isEmpty) continue;
    final w = _weight.firstMatch(chunk) ?? _bareMass.firstMatch(chunk);
    if (w != null) {
      weights.add(
        WeightEntry(
          id: newId(),
          journalEntryId: entry.id,
          day: entry.day,
          kg: kgAssuming(double.parse(w.group(1)!), w.group(2), units),
        ),
      );
    }

    final sc = _sleepClock.firstMatch(chunk);
    if (sc != null) {
      final start = int.parse(sc.group(1)!) + int.parse(sc.group(2)!) / 60.0;
      final end = int.parse(sc.group(3)!) + int.parse(sc.group(4)!) / 60.0;
      _addSleep(sleeps, entry, start, end, quality);
    } else {
      final sf = _sleepFrom.firstMatch(chunk);
      if (sf != null && !chunk.contains(RegExp(r'\d+h'))) {
        var start = _clockHours(sf.group(1)!, sf.group(2), sf.group(3));
        final end = _clockHours(sf.group(4)!, sf.group(5), sf.group(6));
        start = _overnightStart(
          start,
          end,
          hadAmpm: sf.group(3) != null || sf.group(6) != null,
        );
        if ((end - start).abs() > 0.08) {
          _addSleep(sleeps, entry, start, end, quality);
        }
      } else {
        final shm = _sleepHm.firstMatch(chunk);
        final sh = shm ?? _sleepH.firstMatch(chunk);
        final wordH = sh == null ? _sleepWordHours(chunk) : null;
        if (sh != null || wordH != null) {
          final hours = shm != null
              ? int.parse(shm.group(1)!) + int.parse(shm.group(2)!) / 60.0
              : sh != null
              ? double.parse(sh.group(1)!)
              : wordH!;
          _addSleep(sleeps, entry, 7.0 - hours, 7.0, quality);
        } else {
          final smin = _sleepMin.firstMatch(chunk);
          if (smin != null) {
            final hours = int.parse(smin.group(1)!) / 60.0;
            if (hours >= 0.25 && hours <= 16) {
              _addSleep(sleeps, entry, 7.0 - hours, 7.0, quality);
            }
          } else {
            final nap = _nap.firstMatch(chunk);
            if (nap != null) {
              final n = double.parse(nap.group(1)!);
              final unit = nap.group(2)?.toLowerCase() ?? '';
              final hours = unit.startsWith('h') ? n : n / 60.0;
              if (hours >= 0.08 && hours <= 4) {
                final start = entry.at.hour + entry.at.minute / 60.0;
                _addSleep(sleeps, entry, start, start + hours, quality);
              }
            }
          }
        }
      }
    }

    var hadAct = false;
    final session = parseSessionChunk(chunk, entry: entry, bodyKg: bodyKg);
    if (session != null) {
      activities.add(session);
      hadAct = true;
    }

    var setHit = false;
    for (final m in _setX.allMatches(chunk)) {
      setHit |= _addSet(sets, entry, m, units: units, kind: _SetKind.x);
    }
    if (!setHit) {
      final kg = _setKgReps.firstMatch(chunk) ?? _proseSet.firstMatch(chunk);
      if (kg != null) {
        setHit |= _addSet(sets, entry, kg, units: units, kind: _SetKind.kgReps);
      }
    }
    if (!setHit) {
      final nxn = _setNxN.firstMatch(chunk) ?? _setsOf.firstMatch(chunk);
      if (nxn != null) {
        setHit |= _addNxN(sets, entry, nxn, units: units);
      }
    }
    if (!setHit) {
      setHit |= _addBodyCount(sets, entry, chunk);
    }

    final kcalHit = _kcal.firstMatch(chunk);
    if (kcalHit != null && !hadAct) {
      final food = lookupFood(chunk);
      nutrition.add(
        NutritionEntry(
          id: newId(),
          journalEntryId: entry.id,
          day: entry.day,
          label: food?.label ?? chunk.replaceAll(_kcal, '').trim(),
          kcal: double.parse(kcalHit.group(1)!),
          proteinG: food?.proteinG,
          carbsG: food?.carbsG,
          fatG: food?.fatG,
          confirmed: true,
          source: 'parsed',
        ),
      );
    } else if (!hadAct && !setHit) {
      final ate = _ate.firstMatch(chunk);
      final rawFoods = ate?.group(1) ?? chunk;
      final foldedFood = foldLatin(rawFoods);
      final namedCompound = kFoods.any(
        (f) => f.aliases.any((a) {
          final al = foldLatin(a);
          final glue =
              al.contains(' and ') ||
              al.contains(' with ') ||
              al.contains(' z ');
          return glue && foldedFood.contains(al);
        }),
      );
      final parts = (_foodSplit.hasMatch(rawFoods) && !namedCompound)
          ? rawFoods.split(_foodSplit)
          : [rawFoods];
      for (final part in parts) {
        final q = _foodQty(_foodTail(part));
        final rest = _measureOf(q.rest);
        final food =
            lookupFood(rest) ?? lookupFood(_singular(rest)) ?? lookupFood(part);
        if (food == null || kcalHit != null) continue;
        final scaled = _scaleFood(food, q.qty);
        final trivial = food.kcal / food.unitCount <= kTrivialKcal;
        nutrition.add(
          NutritionEntry(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            label: scaled.label,
            kcal: scaled.kcal,
            proteinG: scaled.proteinG,
            carbsG: scaled.carbsG,
            fatG: scaled.fatG,
            confirmed: trivial,
            source: trivial ? 'parsed' : 'estimate',
          ),
        );
      }
      final prot = _protein.firstMatch(chunk);
      if (prot != null && nutrition.isEmpty) {
        final g = double.parse(prot.group(1) ?? prot.group(2)!);
        nutrition.add(
          NutritionEntry(
            id: newId(),
            journalEntryId: entry.id,
            day: entry.day,
            label: 'Protein',
            kcal: g * 4,
            proteinG: g,
            confirmed: true,
            source: 'parsed',
          ),
        );
      }
    }
  }

  if (sleeps.isEmpty) {
    final folded = foldSpoken(entry.text);
    final bed = _bed.firstMatch(folded);
    final woke = _woke.firstMatch(folded);
    if (bed != null && woke != null) {
      var start = _clockHours(bed.group(1)!, bed.group(2), bed.group(3));
      final end = _clockHours(woke.group(1)!, woke.group(2), woke.group(3));
      start = _overnightStart(
        start,
        end,
        hadAmpm: bed.group(3) != null || woke.group(3) != null,
      );
      if ((end - start).abs() > 0.08) {
        _addSleep(sleeps, entry, start, end, quality);
      }
    } else if (bed != null) {
      var start = _clockHours(bed.group(1)!, bed.group(2), bed.group(3));
      if (bed.group(3) == null && start > 0 && start <= 12) {
        start = start == 12 ? 0 : start + 12;
      }
      _addSleep(sleeps, entry, start, start, quality);
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

/// Wake clock on a page that did not also name bedtime. Empty means the
/// morning did not finish last night — we do not invent a start.
double? sleepWakeHoursOf(String text) {
  final folded = foldSpoken(text);
  if (_bed.firstMatch(folded) != null) return null;
  final woke = _woke.firstMatch(folded) ?? _sleptUntil.firstMatch(folded);
  if (woke == null) return null;
  return _clockHours(woke.group(1)!, woke.group(2), woke.group(3));
}

double? sleepQualityOf(String text) {
  final t = foldLatin(text);
  if (_sleepQualityBad.hasMatch(t)) return 0.32;
  if (_sleepQualityGood.hasMatch(t)) return 0.92;
  if (RegExp(r'\b(zle|slabo|okropnie)\b').hasMatch(t) &&
      RegExp(r'\b(spalem|spalam|slept?|sleep)\b').hasMatch(t)) {
    return 0.32;
  }
  if (RegExp(r'\bnie mog[el][ae]m\b').hasMatch(t) &&
      RegExp(r'\b(spac|slept?|sleep)\b').hasMatch(t)) {
    return 0.32;
  }
  return null;
}

String _stripLeadIn(String chunk) {
  var s = chunk.trim();
  final lead = RegExp(
    r"^(?:i(?:['’]ve| have)?|we|just|went\s+(?:for|on)\s+a|(?:did|finished|completed)(?:\s+a)?|last\s+night|(?:this\s+)?(?:morning|afternoon|evening)|tonight|today|yesterday|(?:bylem|bylam)\s+na|na\s+(?:sniadanie|obiad|kolacje)|for\s+(?:breakfast|lunch|dinner|supper|brunch)|(?:breakfast|lunch|dinner|supper|brunch)\s+was)\s+",
    caseSensitive: false,
  );
  while (true) {
    final next = s.replaceFirst(lead, '').trim();
    if (next == s) return s;
    s = next;
  }
}

String _measureOf(String rest) {
  return rest
      .replaceFirst(
        RegExp(
          r'^(?:bowls?|slices?|cups?|pieces?|servings?|plates?|misk[aei]|kromk[aei]|szklank[aei])\s+(?:of\s+)?',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

String _foodTail(String part) {
  var s = part.trim();
  s = s.replaceFirst(
    RegExp(r'^(?:leftover|left[- ]over|yesterdays?)\s+', caseSensitive: false),
    '',
  );
  s = s.replaceFirst(
    RegExp(r'^(?:some|a bit of|a little)\s+', caseSensitive: false),
    '',
  );
  s = s.replaceFirst(
    RegExp(r'^(?:leftover|left[- ]over|yesterdays?)\s+', caseSensitive: false),
    '',
  );
  s = s.replaceFirst(
    RegExp(
      r'^(?:breakfast|lunch|dinner|supper|brunch)\s+was\s+',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceFirst(
    RegExp(
      r'\s+for\s+(?:breakfast|lunch|dinner|supper|brunch)\b.*$',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceFirst(
    RegExp(r'\s+na\s+(?:sniadanie|obiad|kolacje)\b.*$', caseSensitive: false),
    '',
  );
  return s.trim();
}

double _overnightStart(double start, double end, {required bool hadAmpm}) {
  if (!hadAmpm && start > end && start <= 12) {
    return start == 12 ? 0 : start + 12;
  }
  return start;
}

String _singular(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.endsWith('ies') && t.length > 4) {
    return '${t.substring(0, t.length - 3)}y';
  }
  if (t.endsWith('s') && !t.endsWith('ss') && t.length > 3) {
    return t.substring(0, t.length - 1);
  }
  return t;
}

const _wordQty = <String, int>{
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'jeden': 1,
  'jedno': 1,
  'jedna': 1,
  'dwa': 2,
  'dwie': 2,
  'trzy': 3,
  'cztery': 4,
  'piec': 5,
  'szesc': 6,
  'siedem': 7,
  'osiem': 8,
  'dziewiec': 9,
  'dziesiec': 10,
};

double? _sleepWordHours(String chunk) {
  final keys = _wordQty.keys.where((k) => k.length > 1).join('|');
  final m = RegExp(
    '$_sleepVerb\\s+(?:for\\s+)?($keys)\\s+(?:hours?|godzin(?:y|e)?)\\b',
    caseSensitive: false,
  ).firstMatch(chunk);
  if (m == null) return null;
  return _wordQty[m.group(1)!.toLowerCase()]?.toDouble();
}

({int? qty, String rest}) _foodQty(String part) {
  final t = part.trim();
  final numbered =
      RegExp(r'^(\d+)\s*(?:x|×)\s*(.+)$', caseSensitive: false).firstMatch(t) ??
      RegExp(r'^(\d+)\s+(.+)$').firstMatch(t);
  if (numbered != null) {
    final q = int.parse(numbered.group(1)!);
    if (q >= 1 && q <= 12) {
      return (qty: q, rest: numbered.group(2)!.trim());
    }
  }
  final words = _wordQty.keys.join('|');
  final named = RegExp(
    '^($words)\\s+(.+)\$',
    caseSensitive: false,
  ).firstMatch(t);
  if (named != null) {
    return (
      qty: _wordQty[named.group(1)!.toLowerCase()]!,
      rest: named.group(2)!.trim(),
    );
  }
  return (qty: null, rest: t);
}

class _ScaledFood {
  const _ScaledFood({
    required this.label,
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });
  final String label;
  final double kcal;
  final double? proteinG, carbsG, fatG;
}

_ScaledFood _scaleFood(FoodEstimate food, int? qty) {
  final n = (qty ?? food.unitCount).clamp(1, 12);
  final factor = n / food.unitCount;
  final label = n == food.unitCount ? food.label : '${food.label} ×$n';
  double? m(double? v) => v == null ? null : v * factor;
  return _ScaledFood(
    label: label,
    kcal: food.kcal * factor,
    proteinG: m(food.proteinG),
    carbsG: m(food.carbsG),
    fatG: m(food.fatG),
  );
}

void _addSleep(
  List<SleepEntry> sleeps,
  JournalEntry entry,
  double start,
  double end,
  double? quality,
) {
  var startH = start;
  var endH = end;
  if (endH < startH) startH -= 24;
  sleeps.add(
    SleepEntry(
      id: newId(),
      journalEntryId: entry.id,
      day: entry.day,
      startHours: startH,
      endHours: endH,
      quality: quality,
    ),
  );
}

double _clockHours(String h, String? m, String? ampm) {
  var hour = int.parse(h);
  final min = m == null ? 0 : int.parse(m);
  final ap = ampm?.toLowerCase();
  if (ap == 'pm' && hour < 12) hour += 12;
  if (ap == 'am' && hour == 12) hour = 0;
  return hour + min / 60.0;
}

enum _SetKind { x, kgReps }

bool _addSet(
  List<StrengthSet> sets,
  JournalEntry entry,
  RegExpMatch m, {
  required String units,
  required _SetKind kind,
}) {
  final name = m.group(1)?.trim() ?? '';
  if (name.isEmpty) return false;
  final resolved = resolveExercise(name);
  final n2 = double.parse(m.group(2)!);
  final unit = kind == _SetKind.x ? m.group(3) : m.group(3);
  final rpeGroup = m.groupCount >= 6 ? m.group(6) : null;
  final hasUnit = unit != null && unit.isNotEmpty;
  final bodyweight = !hasUnit && _bodyweightIds.contains(resolved.exercise?.id);
  if (kind == _SetKind.kgReps && !hasUnit && resolved.exercise == null) {
    return false;
  }

  late final double weight;
  late final int reps;
  late final int nSets;
  if (bodyweight) {
    weight = 0;
    reps = n2.round();
    nSets = int.tryParse(m.group(4) ?? '') ?? 1;
  } else if (kind == _SetKind.x) {
    weight = kgAssuming(n2, unit, units);
    reps = int.parse(m.group(4)!);
    nSets = int.tryParse(m.group(5) ?? '') ?? 1;
  } else {
    weight = kgAssuming(n2, unit, units);
    reps = int.parse(m.group(4)!);
    nSets = int.tryParse(m.group(5) ?? '') ?? 1;
  }
  if (reps < 1 || reps > 40) return false;
  if (weight < 0 || weight > 400) return false;
  if (!bodyweight && weight == 0) return false;
  final rpe = rpeGroup == null ? null : double.tryParse(rpeGroup);
  if (rpe != null && (rpe < 1 || rpe > 10)) return false;

  sets.add(
    StrengthSet(
      id: newId(),
      journalEntryId: entry.id,
      day: entry.day,
      exerciseId: resolved.exercise?.id ?? 'unknown',
      exerciseName: resolved.name,
      weightKg: weight,
      reps: reps,
      sets: nSets,
      epley1rm: weight == 0 ? null : epley1rm(weight, reps),
      brzycki1rm: weight == 0 ? null : brzycki1rm(weight, reps),
      rpe: rpe,
    ),
  );
  return true;
}

bool _addNxN(
  List<StrengthSet> sets,
  JournalEntry entry,
  RegExpMatch m, {
  required String units,
}) {
  final nSets = int.parse(m.group(1)!);
  final reps = int.parse(m.group(2)!);
  final name = m.group(3)?.trim() ?? '';
  if (name.isEmpty) return false;
  final resolved = resolveExercise(name);
  final bodyweight = _bodyweightIds.contains(resolved.exercise?.id);
  final weightRaw = m.group(4);
  if (weightRaw == null && !bodyweight) return false;
  final weight = weightRaw == null
      ? 0.0
      : kgAssuming(double.parse(weightRaw), m.group(5), units);
  if (nSets < 1 || nSets > 20) return false;
  if (reps < 1 || reps > 40) return false;
  if (weight < 0 || weight > 400) return false;
  if (!bodyweight && weight == 0) return false;
  final rpe = m.group(6) == null ? null : double.tryParse(m.group(6)!);
  if (rpe != null && (rpe < 1 || rpe > 10)) return false;
  sets.add(
    StrengthSet(
      id: newId(),
      journalEntryId: entry.id,
      day: entry.day,
      exerciseId: resolved.exercise?.id ?? 'unknown',
      exerciseName: resolved.name,
      weightKg: weight,
      reps: reps,
      sets: nSets,
      epley1rm: weight == 0 ? null : epley1rm(weight, reps),
      brzycki1rm: weight == 0 ? null : brzycki1rm(weight, reps),
      rpe: rpe,
    ),
  );
  return true;
}

bool _addBodyCount(List<StrengthSet> sets, JournalEntry entry, String chunk) {
  final m = _bwCount.firstMatch(chunk.trim());
  if (m == null) return false;
  final reps = int.parse(m.group(1)!);
  if (reps < 1 || reps > 40) return false;
  final resolved = resolveExercise(m.group(2)!.trim());
  if (!_bodyweightIds.contains(resolved.exercise?.id)) return false;
  sets.add(
    StrengthSet(
      id: newId(),
      journalEntryId: entry.id,
      day: entry.day,
      exerciseId: resolved.exercise!.id,
      exerciseName: resolved.name,
      weightKg: 0,
      reps: reps,
      sets: 1,
    ),
  );
  return true;
}
