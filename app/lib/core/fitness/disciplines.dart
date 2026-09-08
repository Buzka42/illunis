import '../i18n/fold.dart';
import '../strength/canon.dart' show jaroWinkler;

/// A sport or practice the journal can name. Strength lifts stay in the
/// exercise canon; this is everything else a general fitness log covers.
enum DisciplineKind { endurance, sport, mobility, conditioning }

class Discipline {
  const Discipline({
    required this.id,
    required this.label,
    required this.aliases,
    required this.kind,
    required this.met,
    this.cruiseKmPerHour,
  });

  final String id;
  final String label;
  final List<String> aliases;
  final DisciplineKind kind;
  final double met;

  /// Typical speed, used only to turn a bare distance into a duration.
  final double? cruiseKmPerHour;

  bool get tracksPace =>
      kind == DisciplineKind.endurance && (cruiseKmPerHour ?? 0) > 0;
}

const kDisciplines = <Discipline>[
  Discipline(
    id: 'run',
    label: 'Run',
    aliases: [
      'ran',
      'run',
      'running',
      'jog',
      'jogged',
      'jogging',
      '5k',
      '10k',
      'long run',
      'bieg',
      'bieglem',
      'bieglam',
      'biegalem',
      'biegalam',
      'przebieglem',
      'przebieglam',
      'pobiegalem',
      'pobieglam',
      'bieganie',
      'trucht',
    ],
    kind: DisciplineKind.endurance,
    met: 9.8,
    cruiseKmPerHour: 10,
  ),
  Discipline(
    id: 'walk',
    label: 'Walk',
    aliases: [
      'walked',
      'walk',
      'walking',
      'steps',
      'spacer',
      'spacer z psem',
      'spacerowalem',
      'spacerowalam',
      'chodzilem',
      'chodzilam',
      'spacerowanie',
      'chodzenie',
      'marsz',
    ],
    kind: DisciplineKind.endurance,
    met: 3.5,
    cruiseKmPerHour: 5,
  ),
  Discipline(
    id: 'hike',
    label: 'Hike',
    aliases: ['hiked', 'hike', 'hiking', 'trail'],
    kind: DisciplineKind.endurance,
    met: 6.0,
    cruiseKmPerHour: 4.5,
  ),
  Discipline(
    id: 'cycle',
    label: 'Cycle',
    aliases: [
      'cycled',
      'cycle',
      'cycling',
      'rode',
      'ride',
      'biked',
      'bike',
      'biking',
      'rower',
      'rowerem',
      'rowerze',
      'na rowerze',
      'jezdzilem na rowerze',
      'jezdzilam na rowerze',
    ],
    kind: DisciplineKind.endurance,
    met: 7.5,
    cruiseKmPerHour: 20,
  ),
  Discipline(
    id: 'swim',
    label: 'Swim',
    aliases: [
      'swam',
      'swim',
      'swimming',
      'plywanie',
      'plywalem',
      'plywalam',
      'basen',
      'basenie',
      'na basenie',
    ],
    kind: DisciplineKind.endurance,
    met: 7.0,
    cruiseKmPerHour: 2.5,
  ),
  Discipline(
    id: 'row',
    label: 'Row',
    aliases: ['rowed', 'row', 'rowing', 'erg'],
    kind: DisciplineKind.endurance,
    met: 7.0,
    cruiseKmPerHour: 4,
  ),
  Discipline(
    id: 'ski',
    label: 'Ski',
    aliases: ['skied', 'ski', 'skiing', 'nordic'],
    kind: DisciplineKind.endurance,
    met: 7.0,
    cruiseKmPerHour: 10,
  ),
  Discipline(
    id: 'elliptical',
    label: 'Elliptical',
    aliases: ['elliptical', 'cross trainer'],
    kind: DisciplineKind.endurance,
    met: 5.0,
    cruiseKmPerHour: 8,
  ),
  Discipline(
    id: 'jump-rope',
    label: 'Jump rope',
    aliases: ['skipped', 'skipping', 'jump rope', 'jump-rope'],
    kind: DisciplineKind.conditioning,
    met: 11.0,
  ),
  Discipline(
    id: 'football',
    label: 'Football',
    aliases: ['football', 'soccer', 'footy'],
    kind: DisciplineKind.sport,
    met: 7.0,
  ),
  Discipline(
    id: 'basketball',
    label: 'Basketball',
    aliases: ['basketball', 'hoops'],
    kind: DisciplineKind.sport,
    met: 6.5,
  ),
  Discipline(
    id: 'tennis',
    label: 'Tennis',
    aliases: ['tennis'],
    kind: DisciplineKind.sport,
    met: 7.3,
  ),
  Discipline(
    id: 'climbing',
    label: 'Climbing',
    aliases: ['climbed', 'climbing', 'bouldering', 'boulder'],
    kind: DisciplineKind.sport,
    met: 8.0,
  ),
  Discipline(
    id: 'martial-arts',
    label: 'Martial arts',
    aliases: [
      'boxing',
      'kickboxing',
      'muay thai',
      'bjj',
      'jiu jitsu',
      'judo',
      'karate',
      'mma',
      'sparring',
    ],
    kind: DisciplineKind.sport,
    met: 10.0,
  ),
  Discipline(
    id: 'dance',
    label: 'Dance',
    aliases: ['danced', 'dance', 'dancing', 'zumba'],
    kind: DisciplineKind.sport,
    met: 5.0,
  ),
  Discipline(
    id: 'rugby',
    label: 'Rugby',
    aliases: ['rugby'],
    kind: DisciplineKind.sport,
    met: 8.0,
  ),
  Discipline(
    id: 'volleyball',
    label: 'Volleyball',
    aliases: ['volleyball', 'volley'],
    kind: DisciplineKind.sport,
    met: 6.0,
  ),
  Discipline(
    id: 'golf',
    label: 'Golf',
    aliases: ['golf', 'golfed'],
    kind: DisciplineKind.sport,
    met: 4.8,
  ),
  Discipline(
    id: 'squash',
    label: 'Squash',
    aliases: ['squash'],
    kind: DisciplineKind.sport,
    met: 12.0,
  ),
  Discipline(
    id: 'badminton',
    label: 'Badminton',
    aliases: ['badminton'],
    kind: DisciplineKind.sport,
    met: 5.5,
  ),
  Discipline(
    id: 'cricket',
    label: 'Cricket',
    aliases: ['cricket'],
    kind: DisciplineKind.sport,
    met: 4.8,
  ),
  Discipline(
    id: 'padel',
    label: 'Padel',
    aliases: ['padel', 'paddle', 'paddle tennis'],
    kind: DisciplineKind.sport,
    met: 6.0,
  ),
  Discipline(
    id: 'surf',
    label: 'Surf',
    aliases: ['surf', 'surfed', 'surfing'],
    kind: DisciplineKind.sport,
    met: 6.0,
  ),
  Discipline(
    id: 'crossfit',
    label: 'CrossFit',
    aliases: ['crossfit', 'cross fit', 'wod'],
    kind: DisciplineKind.conditioning,
    met: 8.0,
  ),
  Discipline(
    id: 'yoga',
    label: 'Yoga',
    aliases: ['yoga', 'vinyasa', 'yin'],
    kind: DisciplineKind.mobility,
    met: 3.0,
  ),
  Discipline(
    id: 'pilates',
    label: 'Pilates',
    aliases: ['pilates'],
    kind: DisciplineKind.mobility,
    met: 3.5,
  ),
  Discipline(
    id: 'mobility',
    label: 'Mobility',
    aliases: ['stretch', 'stretched', 'stretching', 'mobility', 'foam roll'],
    kind: DisciplineKind.mobility,
    met: 2.5,
  ),
  Discipline(
    id: 'hiit',
    label: 'HIIT',
    aliases: ['hiit', 'intervals', 'tabata', 'circuit', 'cardio'],
    kind: DisciplineKind.conditioning,
    met: 8.0,
  ),
  Discipline(
    id: 'gym',
    label: 'Gym',
    aliases: [
      'gym',
      'workout',
      'lifted',
      'lifting',
      'weights',
      'strength',
      'silownia',
      'silownie',
      'silowni',
      'silke',
      'silka',
      'trening',
      'cwiczylem',
      'cwiczylam',
      'trenowalem',
      'trenowalam',
      'cwiczenia',
    ],
    kind: DisciplineKind.conditioning,
    met: 6.0,
  ),
  Discipline(
    id: 'stairs',
    label: 'Stairs',
    aliases: ['stairs', 'stair'],
    kind: DisciplineKind.conditioning,
    met: 8.8,
  ),
];

final _index = () {
  final m = <String, Discipline>{};
  for (final d in kDisciplines) {
    m[_norm(d.label)] = d;
    m[_norm(d.id.replaceAll('-', ' '))] = d;
    for (final a in d.aliases) {
      m[_norm(a)] = d;
    }
  }
  return m;
}();

String _norm(String s) =>
    foldLatin(s).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

({Discipline? discipline, String name, bool unknown}) resolveDiscipline(
  String raw,
) {
  final n = _norm(raw);
  if (n.isEmpty) return (discipline: null, name: raw.trim(), unknown: true);
  final hit = _index[n];
  if (hit != null) return (discipline: hit, name: hit.label, unknown: false);
  Discipline? best;
  var bestScore = 0.0;
  for (final d in kDisciplines) {
    for (final candidate in [
      d.label,
      d.id.replaceAll('-', ' '),
      ...d.aliases,
    ]) {
      final s = jaroWinkler(_norm(candidate), n);
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
  }
  if (best != null && bestScore >= 0.88) {
    return (discipline: best, name: best.label, unknown: false);
  }
  return (discipline: null, name: raw.trim(), unknown: true);
}

Discipline? disciplineIn(String raw) {
  final n = _norm(raw);
  if (n.isEmpty) return null;
  Discipline? best;
  var bestLen = 0;
  for (final d in kDisciplines) {
    for (final a in [...d.aliases, d.label.toLowerCase()]) {
      final token = a.trim();
      if (token.isEmpty) continue;
      if (RegExp(
            '\\b${RegExp.escape(token)}\\b',
            caseSensitive: false,
          ).hasMatch(n) &&
          token.length > bestLen) {
        best = d;
        bestLen = token.length;
      }
    }
  }
  return best;
}

String disciplineLabel(String id) {
  for (final d in kDisciplines) {
    if (d.id == id) return d.label.toUpperCase();
  }
  return id.toUpperCase();
}
