import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../i18n/fold.dart';

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.aliases,
    required this.muscles,
    required this.isCompound,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final List<String> muscles;
  final bool isCompound;
}

/// A working canon: the lifts people actually type, plus aliases.
/// Hyper Planner's library is 250 deep; this is the subset that a journal
/// line will hit, with a fuzzy fallback for the rest.
const kCanon = <Exercise>[
  Exercise(
    id: 'barbell-squat',
    name: 'Barbell squat',
    aliases: ['squat', 'back squat', 'bb squat', 'przysiad', 'przysiady'],
    muscles: ['quads', 'glutes'],
    isCompound: true,
  ),
  Exercise(
    id: 'front-squat',
    name: 'Front squat',
    aliases: ['front squats'],
    muscles: ['quads'],
    isCompound: true,
  ),
  Exercise(
    id: 'goblet-squat',
    name: 'Goblet squat',
    aliases: [],
    muscles: ['quads'],
    isCompound: true,
  ),
  Exercise(
    id: 'conventional-deadlift',
    name: 'Deadlift',
    aliases: [
      'dl',
      'deadlift',
      'conventional deadlift',
      'martwy',
      'martwy ciag',
    ],
    muscles: ['posterior chain'],
    isCompound: true,
  ),
  Exercise(
    id: 'romanian-deadlift',
    name: 'Romanian deadlift',
    aliases: ['rdl'],
    muscles: ['hamstrings', 'glutes'],
    isCompound: true,
  ),
  Exercise(
    id: 'barbell-bench-press',
    name: 'Barbell bench press',
    aliases: [
      'bench',
      'bench press',
      'bb bench',
      'wyciskanie',
      'wyciskanie lezac',
    ],
    muscles: ['chest', 'triceps'],
    isCompound: true,
  ),
  Exercise(
    id: 'incline-bench-press',
    name: 'Incline bench press',
    aliases: ['incline bench'],
    muscles: ['chest'],
    isCompound: true,
  ),
  Exercise(
    id: 'dumbbell-bench-press',
    name: 'Dumbbell bench press',
    aliases: ['db bench'],
    muscles: ['chest'],
    isCompound: true,
  ),
  Exercise(
    id: 'overhead-press',
    name: 'Overhead press',
    aliases: [
      'ohp',
      'press',
      'military press',
      'shoulder press',
      'wyciskanie zolnierskie',
      'wyciskanie stojac',
    ],
    muscles: ['shoulders', 'triceps'],
    isCompound: true,
  ),
  Exercise(
    id: 'push-press',
    name: 'Push press',
    aliases: [],
    muscles: ['shoulders'],
    isCompound: true,
  ),
  Exercise(
    id: 'barbell-row',
    name: 'Barbell row',
    aliases: ['row', 'bent over row', 'bb row', 'wioslowanie'],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 'pendlay-row',
    name: 'Pendlay row',
    aliases: [],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 'pull-up',
    name: 'Pull-up',
    aliases: [
      'pullup',
      'pull ups',
      'pull-ups',
      'chin up',
      'chin-up',
      'podciaganie',
      'podciagania',
    ],
    muscles: ['lats', 'biceps'],
    isCompound: true,
  ),
  Exercise(
    id: 'lat-pulldown',
    name: 'Lat pulldown',
    aliases: ['pulldown'],
    muscles: ['lats'],
    isCompound: true,
  ),
  Exercise(
    id: 'hip-thrust',
    name: 'Hip thrust',
    aliases: ['barbell hip thrust'],
    muscles: ['glutes'],
    isCompound: true,
  ),
  Exercise(
    id: 'lunge',
    name: 'Lunge',
    aliases: ['walking lunge', 'reverse lunge'],
    muscles: ['quads', 'glutes'],
    isCompound: true,
  ),
  Exercise(
    id: 'leg-press',
    name: 'Leg press',
    aliases: [],
    muscles: ['quads'],
    isCompound: true,
  ),
  Exercise(
    id: 'leg-extension',
    name: 'Leg extension',
    aliases: [],
    muscles: ['quads'],
    isCompound: false,
  ),
  Exercise(
    id: 'lying-leg-curl',
    name: 'Lying leg curl',
    aliases: ['leg curl', 'ham curl'],
    muscles: ['hamstrings'],
    isCompound: false,
  ),
  Exercise(
    id: 'seated-leg-curl',
    name: 'Seated leg curl',
    aliases: [],
    muscles: ['hamstrings'],
    isCompound: false,
  ),
  Exercise(
    id: 'calf-raise',
    name: 'Calf raise',
    aliases: ['standing calf raise'],
    muscles: ['calves'],
    isCompound: false,
  ),
  Exercise(
    id: 'barbell-curl',
    name: 'Barbell curl',
    aliases: ['curl', 'bicep curl', 'bb curl'],
    muscles: ['biceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'dumbbell-curl',
    name: 'Dumbbell curl',
    aliases: ['db curl', 'hammer curl'],
    muscles: ['biceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'triceps-pushdown',
    name: 'Triceps pushdown',
    aliases: ['pushdown', 'cable pushdown'],
    muscles: ['triceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'skull-crusher',
    name: 'Skull crusher',
    aliases: ['lying triceps extension'],
    muscles: ['triceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'lateral-raise',
    name: 'Lateral raise',
    aliases: ['side raise', 'db lateral raise'],
    muscles: ['shoulders'],
    isCompound: false,
  ),
  Exercise(
    id: 'rear-delt-fly',
    name: 'Rear delt fly',
    aliases: ['reverse pec deck', 'face pull', 'facepull'],
    muscles: ['shoulders'],
    isCompound: false,
  ),
  Exercise(
    id: 'dip',
    name: 'Dip',
    aliases: ['dips', 'chest dip'],
    muscles: ['chest', 'triceps'],
    isCompound: true,
  ),
  Exercise(
    id: 'plank',
    name: 'Plank',
    aliases: [],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'cable-crunch',
    name: 'Cable crunch',
    aliases: ['crunch'],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'ab-wheel',
    name: 'Ab wheel',
    aliases: ['ab wheel rollout'],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'sumo-deadlift',
    name: 'Sumo deadlift',
    aliases: ['sumo dl'],
    muscles: ['glutes', 'quads'],
    isCompound: true,
  ),
  Exercise(
    id: 'trap-bar-deadlift',
    name: 'Trap bar deadlift',
    aliases: ['trap bar', 'hex bar deadlift'],
    muscles: ['quads', 'posterior chain'],
    isCompound: true,
  ),
  Exercise(
    id: 'rack-pull',
    name: 'Rack pull',
    aliases: [],
    muscles: ['posterior chain'],
    isCompound: true,
  ),
  Exercise(
    id: 'good-morning',
    name: 'Good morning',
    aliases: [],
    muscles: ['hamstrings'],
    isCompound: true,
  ),
  Exercise(
    id: 'bulgarian-split-squat',
    name: 'Bulgarian split squat',
    aliases: ['bss', 'split squat'],
    muscles: ['quads', 'glutes'],
    isCompound: true,
  ),
  Exercise(
    id: 'step-up',
    name: 'Step-up',
    aliases: ['step ups'],
    muscles: ['quads', 'glutes'],
    isCompound: true,
  ),
  Exercise(
    id: 'hack-squat',
    name: 'Hack squat',
    aliases: [],
    muscles: ['quads'],
    isCompound: true,
  ),
  Exercise(
    id: 'leg-press-calf',
    name: 'Seated calf raise',
    aliases: ['seated calf'],
    muscles: ['calves'],
    isCompound: false,
  ),
  Exercise(
    id: 'glute-ham-raise',
    name: 'Glute ham raise',
    aliases: ['ghr', 'nordic curl'],
    muscles: ['hamstrings'],
    isCompound: true,
  ),
  Exercise(
    id: 'back-extension',
    name: 'Back extension',
    aliases: ['hyperextension', 'reverse hyper'],
    muscles: ['posterior chain'],
    isCompound: false,
  ),
  Exercise(
    id: 'close-grip-bench',
    name: 'Close-grip bench press',
    aliases: ['cgbp', 'close grip bench'],
    muscles: ['triceps', 'chest'],
    isCompound: true,
  ),
  Exercise(
    id: 'floor-press',
    name: 'Floor press',
    aliases: [],
    muscles: ['chest', 'triceps'],
    isCompound: true,
  ),
  Exercise(
    id: 'dumbbell-incline-press',
    name: 'Dumbbell incline press',
    aliases: ['db incline'],
    muscles: ['chest'],
    isCompound: true,
  ),
  Exercise(
    id: 'machine-chest-press',
    name: 'Machine chest press',
    aliases: ['chest press'],
    muscles: ['chest'],
    isCompound: true,
  ),
  Exercise(
    id: 'pec-deck',
    name: 'Pec deck',
    aliases: ['chest fly', 'cable fly', 'db fly'],
    muscles: ['chest'],
    isCompound: false,
  ),
  Exercise(
    id: 'push-up',
    name: 'Push-up',
    aliases: [
      'pushup',
      'push ups',
      'push-ups',
      'press ups',
      'pompki',
      'pompka',
    ],
    muscles: ['chest', 'triceps'],
    isCompound: true,
  ),
  Exercise(
    id: 'seated-dumbbell-press',
    name: 'Seated dumbbell press',
    aliases: ['db press', 'db ohp', 'arnold press'],
    muscles: ['shoulders'],
    isCompound: true,
  ),
  Exercise(
    id: 'upright-row',
    name: 'Upright row',
    aliases: [],
    muscles: ['shoulders'],
    isCompound: true,
  ),
  Exercise(
    id: 'front-raise',
    name: 'Front raise',
    aliases: [],
    muscles: ['shoulders'],
    isCompound: false,
  ),
  Exercise(
    id: 'shrug',
    name: 'Shrug',
    aliases: ['barbell shrug', 'db shrug'],
    muscles: ['traps'],
    isCompound: false,
  ),
  Exercise(
    id: 'seated-row',
    name: 'Seated row',
    aliases: ['cable row', 'machine row'],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 't-bar-row',
    name: 'T-bar row',
    aliases: ['tbar row'],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 'chest-supported-row',
    name: 'Chest-supported row',
    aliases: ['supported row'],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 'one-arm-row',
    name: 'One-arm dumbbell row',
    aliases: ['db row', 'one arm row'],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 'inverted-row',
    name: 'Inverted row',
    aliases: ['bodyweight row'],
    muscles: ['back'],
    isCompound: true,
  ),
  Exercise(
    id: 'straight-arm-pulldown',
    name: 'Straight-arm pulldown',
    aliases: [],
    muscles: ['lats'],
    isCompound: false,
  ),
  Exercise(
    id: 'preacher-curl',
    name: 'Preacher curl',
    aliases: [],
    muscles: ['biceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'cable-curl',
    name: 'Cable curl',
    aliases: [],
    muscles: ['biceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'incline-curl',
    name: 'Incline curl',
    aliases: [],
    muscles: ['biceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'overhead-extension',
    name: 'Overhead triceps extension',
    aliases: ['overhead extension', 'french press'],
    muscles: ['triceps'],
    isCompound: false,
  ),
  Exercise(
    id: 'hip-abduction',
    name: 'Hip abduction',
    aliases: ['abductor'],
    muscles: ['glutes'],
    isCompound: false,
  ),
  Exercise(
    id: 'hip-adduction',
    name: 'Hip adduction',
    aliases: ['adductor'],
    muscles: ['adductors'],
    isCompound: false,
  ),
  Exercise(
    id: 'farmers-carry',
    name: 'Farmer\'s carry',
    aliases: ['farmers walk', 'farmer carry'],
    muscles: ['core', 'traps'],
    isCompound: true,
  ),
  Exercise(
    id: 'kettlebell-swing',
    name: 'Kettlebell swing',
    aliases: ['kb swing', 'swing'],
    muscles: ['glutes', 'hamstrings'],
    isCompound: true,
  ),
  Exercise(
    id: 'thruster',
    name: 'Thruster',
    aliases: [],
    muscles: ['quads', 'shoulders'],
    isCompound: true,
  ),
  Exercise(
    id: 'power-clean',
    name: 'Power clean',
    aliases: ['clean'],
    muscles: ['posterior chain'],
    isCompound: true,
  ),
  Exercise(
    id: 'hanging-leg-raise',
    name: 'Hanging leg raise',
    aliases: ['hlr', 'toes to bar'],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'sit-up',
    name: 'Sit-up',
    aliases: ['situp', 'sit-ups', 'sit ups', 'crunches', 'brzuszki'],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'russian-twist',
    name: 'Russian twist',
    aliases: [],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'dead-bug',
    name: 'Dead bug',
    aliases: [],
    muscles: ['core'],
    isCompound: false,
  ),
  Exercise(
    id: 'face-pull',
    name: 'Face pull',
    aliases: ['facepulls'],
    muscles: ['shoulders'],
    isCompound: false,
  ),
];

final _index = () {
  final m = <String, Exercise>{};
  for (final e in kCanon) {
    m[_norm(e.name)] = e;
    m[_norm(e.id.replaceAll('-', ' '))] = e;
    for (final a in e.aliases) {
      m[_norm(a)] = e;
    }
  }
  return m;
}();

String _norm(String s) =>
    foldLatin(s).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Exact alias, then Jaro–Winkler ≥ 0.88, else an unknown kept as typed.
({Exercise? exercise, String name, bool unknown}) resolveExercise(String raw) {
  final n = _norm(raw);
  if (n.isEmpty) return (exercise: null, name: raw.trim(), unknown: true);
  final hit = _index[n];
  if (hit != null) return (exercise: hit, name: hit.name, unknown: false);
  Exercise? best;
  var bestScore = 0.0;
  for (final e in kCanon) {
    for (final candidate in [e.name, e.id.replaceAll('-', ' '), ...e.aliases]) {
      final s = jaroWinkler(_norm(candidate), n);
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
  }
  if (best != null && bestScore >= 0.88) {
    return (exercise: best, name: best.name, unknown: false);
  }
  return (exercise: null, name: raw.trim(), unknown: true);
}

double jaroWinkler(String s1, String s2) {
  if (s1 == s2) return 1;
  if (s1.isEmpty || s2.isEmpty) return 0;
  final matchDist = (math.max(s1.length, s2.length) / 2).floor() - 1;
  final s1Match = List<bool>.filled(s1.length, false);
  final s2Match = List<bool>.filled(s2.length, false);
  var matches = 0;
  for (var i = 0; i < s1.length; i++) {
    final start = math.max(0, i - matchDist);
    final end = math.min(i + matchDist + 1, s2.length);
    for (var j = start; j < end; j++) {
      if (s2Match[j] || s1[i] != s2[j]) continue;
      s1Match[i] = true;
      s2Match[j] = true;
      matches++;
      break;
    }
  }
  if (matches == 0) return 0;
  var t = 0;
  var k = 0;
  for (var i = 0; i < s1.length; i++) {
    if (!s1Match[i]) continue;
    while (!s2Match[k]) {
      k++;
    }
    if (s1[i] != s2[k]) t++;
    k++;
  }
  final m = matches.toDouble();
  final jaro = (m / s1.length + m / s2.length + (m - t / 2) / m) / 3;
  var prefix = 0;
  for (var i = 0; i < math.min(4, math.min(s1.length, s2.length)); i++) {
    if (s1[i] == s2[i]) {
      prefix++;
    } else {
      break;
    }
  }
  return jaro + prefix * 0.1 * (1 - jaro);
}
