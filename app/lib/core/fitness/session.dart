import '../db/records.dart';
import 'disciplines.dart';
import 'format.dart';

final _kcal = RegExp(r'(\d+(?:\.\d+)?)\s*k(?:cal|c)\b', caseSensitive: false);
final _dist = RegExp(
  r'(\d+(?:\.\d+)?)\s*(kilometr(?:y|ow)?|kilometres?|km|mi|miles|mile|meters?|k|m)\b',
  caseSensitive: false,
);
final _inHms = RegExp(
  r'\bin\s+(\d+)\s*h(?:ours?)?\s*(?:(\d+)\s*m(?:in(?:utes?)?)?)?',
  caseSensitive: false,
);
final _inClock = RegExp(
  r'\bin\s+(\d+)[:.](\d{2})(?:[:.](\d{2}))?',
  caseSensitive: false,
);
final _inMin = RegExp(
  r'\bin\s+(\d+(?:\.\d+)?)\s*(min|mins|minutes)\b',
  caseSensitive: false,
);
final _forMin = RegExp(
  r'\b(?:for\s+)?(\d+(?:\.\d+)?)\s*(min|mins|minutes|minut(?:y|e)?|h|hr|hours?|godzin(?:y|e)?)\b',
  caseSensitive: false,
);
final _paceMark = RegExp(
  r"(?:@|at|pace)\s+(\d+)[:.'](\d{2})\s*(?:/|per\s*)k(?:m)?|(\d+)[:.'](\d{2})\s*/\s*k(?:m)?",
  caseSensitive: false,
);
final _rpeMark = RegExp(
  r'(?:rpe|effort)\s*(\d+(?:\.\d+)?)',
  caseSensitive: false,
);
final _hrMark = RegExp(r'(\d{2,3})\s*(?:bpm|hr)\b', caseSensitive: false);
final _played = RegExp(
  r'\bplayed\s+([a-z][a-z \-]{1,24})',
  caseSensitive: false,
);
final _liftShape = RegExp(
  r'\b\d+\s*(kg|kgs|kilos?|lb|lbs|pounds|#)\b.*([x×]|reps?)|([x×]|reps?).*\b\d+\s*(kg|kgs|kilos?|lb|lbs|pounds|#)\b',
  caseSensitive: false,
);
final _steps = RegExp(r'\b(\d{3,6})\s*steps\b', caseSensitive: false);
final _effortMark = RegExp(
  r'\b(easy|recovery|steady|tempo|threshold|intervals?|fartlek|race|long)\b',
  caseSensitive: false,
);

const kEfforts = {'easy', 'steady', 'tempo', 'intervals', 'race', 'long'};

/// Pull a session out of one journal chunk. Null means this line is not
/// movement — lifts and meals keep their own parsers.
ActivityEntry? parseSessionChunk(
  String chunk, {
  required JournalEntry entry,
  required double bodyKg,
}) {
  if (_liftShape.hasMatch(chunk)) return null;
  if (RegExp(r'\bstep[- ]?ups?\b', caseSensitive: false).hasMatch(chunk)) {
    return null;
  }
  if (RegExp(
    r'\b(ate|had|eaten|eating|drank|drink|drunk|grabbed|ordered|snacked|kcal|calories?|protein|zjadlem|zjadlam|jadlem|jadlam|wypilem|wypilam)\b',
    caseSensitive: false,
  ).hasMatch(chunk)) {
    return null;
  }

  var disc = disciplineIn(chunk);
  final played = _played.firstMatch(chunk);
  if (played != null) {
    final hit = resolveDiscipline(played.group(1)!);
    if (hit.discipline != null) disc = hit.discipline;
  }

  double? km;
  final dist = _dist.firstMatch(chunk);
  if (dist != null) {
    km = kmFromUnit(double.parse(dist.group(1)!), dist.group(2)!);
  }
  km ??= _raceKm(chunk);

  final steps = _steps.firstMatch(chunk);
  if (steps != null) {
    disc ??= kDisciplines.firstWhere((d) => d.id == 'walk');
    km ??= int.parse(steps.group(1)!) * 0.0008;
  }

  if (disc == null) {
    final compact = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*k(?:m)?\b',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (compact != null || km != null) {
      disc = kDisciplines.firstWhere((d) => d.id == 'run');
    }
  }
  if (disc == null &&
      RegExp(
        r'\b(trained|lifted|workout|weights)\b',
        caseSensitive: false,
      ).hasMatch(chunk)) {
    disc = kDisciplines.firstWhere((d) => d.id == 'gym');
  }
  if (disc == null) return null;

  final effort = effortIn(chunk);
  if (disc.id == 'hiit' && km != null) {
    final runWord = RegExp(
      r'\b(run|ran|jog|k|km|marathon)\b',
      caseSensitive: false,
    ).hasMatch(chunk);
    if (runWord || effort == 'intervals') {
      disc = kDisciplines.firstWhere((d) => d.id == 'run');
    }
  }

  var minutes = _durationMinutes(chunk, distanceKm: km);
  final pace = _paceSeconds(chunk);
  if (minutes == null && pace != null && km != null && km > 0) {
    minutes = (pace * km) / 60.0;
  }
  if (minutes == null && km != null && (disc.cruiseKmPerHour ?? 0) > 0) {
    minutes = (km / disc.cruiseKmPerHour!) * 60.0;
  }
  if (minutes == null && km == null && disc.kind != DisciplineKind.endurance) {
    final lone = RegExp(r'\b(\d{2,3})\b').firstMatch(chunk);
    if (lone != null) {
      final n = double.parse(lone.group(1)!);
      if (n >= 10 && n <= 180) minutes = n;
    }
  }
  if (minutes == null && km == null) return null;
  if (minutes != null && (minutes <= 0 || minutes > 16 * 60)) return null;

  final derivedPace =
      pace ??
      (km != null && minutes != null
          ? paceSecPerKm(km: km, minutes: minutes)
          : null);

  final explicit = _kcal.firstMatch(chunk);
  final hours = (minutes ?? 0) / 60.0;
  final kcal = explicit != null
      ? double.parse(explicit.group(1)!)
      : disc.met * bodyKg * (hours <= 0 ? 0.25 : hours);
  if (kcal <= 0 || kcal > 4000) return null;

  final rpe = double.tryParse(_rpeMark.firstMatch(chunk)?.group(1) ?? '');
  final hr = double.tryParse(_hrMark.firstMatch(chunk)?.group(1) ?? '');

  return ActivityEntry(
    id: newId(),
    journalEntryId: entry.id,
    day: entry.day,
    label: disc.label,
    disciplineId: disc.id,
    kcal: kcal,
    minutes: minutes,
    distanceKm: km,
    paceSecPerKm: disc.tracksPace ? derivedPace : null,
    rpe: rpe != null && rpe >= 1 && rpe <= 10 ? rpe : null,
    hrAvg: hr != null && hr >= 40 && hr <= 220 ? hr : null,
    effort: effort,
    confirmed: explicit != null,
    source: explicit != null ? 'parsed' : 'estimate',
  );
}

/// easy | steady | tempo | intervals | race | long, when the line said so.
String? effortIn(String chunk) {
  final m = _effortMark.firstMatch(chunk);
  if (m == null) return null;
  switch (m.group(1)!.toLowerCase()) {
    case 'easy':
    case 'recovery':
      return 'easy';
    case 'steady':
      return 'steady';
    case 'tempo':
    case 'threshold':
      return 'tempo';
    case 'interval':
    case 'intervals':
    case 'fartlek':
      return 'intervals';
    case 'race':
      return 'race';
    case 'long':
      return 'long';
    default:
      return null;
  }
}

String? normalizeEffort(String? raw) {
  if (raw == null) return null;
  final n = raw.toLowerCase().trim();
  if (kEfforts.contains(n)) return n;
  return effortIn(n);
}

double? _raceKm(String chunk) {
  final n = chunk.toLowerCase();
  final half =
      n.contains('half marathon') ||
      n.contains('half-marathon') ||
      n.contains('halfmarathon');
  final full = !half && RegExp(r'\bmarathon\b').hasMatch(n);
  if (!half && !full) return null;
  final anchored =
      RegExp(
        r'\b(ran|run|jog|raced|race|finished|completed|did)\b',
        caseSensitive: false,
      ).hasMatch(n) ||
      _inClock.hasMatch(chunk) ||
      _inHms.hasMatch(chunk);
  if (!anchored) return null;
  return half ? 21.0975 : 42.195;
}

double? _durationMinutes(String chunk, {double? distanceKm}) {
  final hms = _inHms.firstMatch(chunk);
  if (hms != null) {
    final h = double.parse(hms.group(1)!);
    final m = hms.group(2) == null ? 0.0 : double.parse(hms.group(2)!);
    return h * 60 + m;
  }
  final clock = _inClock.firstMatch(chunk);
  if (clock != null) {
    final a = int.parse(clock.group(1)!);
    final b = int.parse(clock.group(2)!);
    final c = clock.group(3) == null ? 0 : int.parse(clock.group(3)!);
    final asHours = c > 0 || (distanceKm != null && distanceKm >= 12 && a <= 6);
    if (asHours) return a * 60.0 + b + c / 60.0;
    return a + b / 60.0 + c / 3600.0;
  }
  final inMin = _inMin.firstMatch(chunk);
  if (inMin != null) return double.parse(inMin.group(1)!);
  final named = _forMin.firstMatch(chunk);
  if (named != null) {
    final n = double.parse(named.group(1)!);
    final u = named.group(2)!.toLowerCase();
    if (u.startsWith('h') || u.startsWith('godzin')) return n * 60;
    return n;
  }
  return null;
}

double? _paceSeconds(String chunk) {
  final m = _paceMark.firstMatch(chunk);
  if (m == null) return null;
  final min = int.parse(m.group(1) ?? m.group(3)!);
  final sec = int.parse(m.group(2) ?? m.group(4)!);
  final total = min * 60 + sec;
  if (total < 90 || total > 900) return null;
  return total.toDouble();
}
