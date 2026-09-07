import '../i18n/fold.dart';

/// A clock or a time of day on a journal line is the time of the page, not
/// prose. Leading (`7:30 ran 5k`, `this morning ran 5k`) and trailing
/// (`ran 5k this morning`, `ate oatmeal at 8am`, `ran 5k yesterday`) both
/// stamp; the marker is stripped so the list does not show the hour twice.
/// `last night` is yesterday unless the rest is a sleep duration or quality.
/// Bare `7h` and a duration like `in 24:30` are left alone.
class StampedLine {
  const StampedLine({
    required this.text,
    this.hour,
    this.minute,
    this.daysBack = 0,
  });

  final String text;
  final int? hour;
  final int? minute;
  final int daysBack;

  DateTime apply(DateTime fallback) {
    var base = fallback;
    if (daysBack != 0) {
      final d = DateTime(
        fallback.year,
        fallback.month,
        fallback.day,
      ).subtract(Duration(days: daysBack));
      base = DateTime(
        d.year,
        d.month,
        d.day,
        fallback.hour,
        fallback.minute,
        fallback.second,
      );
    }
    if (hour == null) return base;
    return DateTime(base.year, base.month, base.day, hour!, minute ?? 0);
  }
}

final _leadYesterday = RegExp(
  r'^(?:yesterday|wczoraj)\s+',
  caseSensitive: false,
);

final _leadLastNight = RegExp(
  r'^(?:last\s+night|last\s+evening|wczoraj\s+wieczorem)\s+',
  caseSensitive: false,
);

final _leadClock = RegExp(
  r'^(?:(?:this\s+)?(?:morning|afternoon|evening|tonight)\s+)?(?:(?:around|about|at|o)\s+)*(\d{1,2})[:.](\d{2})(?:\s*(am|pm))?\s+',
  caseSensitive: false,
);

final _leadAmpm = RegExp(
  r'^(?:(?:this\s+)?(?:morning|afternoon|evening|tonight)\s+)?(?:(?:around|about|at|o)\s+)*(\d{1,2})\s*(am|pm)\b\s+',
  caseSensitive: false,
);

final _trailYesterday = RegExp(
  r'\s+(?:yesterday|wczoraj)\s*$',
  caseSensitive: false,
);

final _trailLastNight = RegExp(
  r'\s+(?:last\s+night|last\s+evening|wczoraj\s+wieczorem)\s*$',
  caseSensitive: false,
);

final _sleepStaysOnLogDay = RegExp(
  r'\b(slept?|spalem|spalam|sleep)\b',
  caseSensitive: false,
);

StampedLine stampJournalLine(String raw) {
  var t = foldDecimal(raw.trim());
  var daysBack = 0;
  int? hour;
  int? minute;
  final y = _leadYesterday.firstMatch(t);
  if (y != null) {
    final rest = t.substring(y.end).trim();
    if (rest.isNotEmpty) {
      t = rest;
      daysBack = 1;
    }
  }
  if (daysBack == 0) {
    final ln = _leadLastNight.firstMatch(t);
    if (ln != null) {
      final rest = t.substring(ln.end).trim();
      if (rest.isNotEmpty) {
        t = rest;
        if (!_sleepStaysOnLogDay.hasMatch(rest)) daysBack = 1;
      }
    }
  }
  final lead = _consumeLead(t);
  if (lead != null) {
    t = lead.text;
    hour = lead.hour;
    minute = lead.minute;
  }
  final trailY = _trailYesterday.firstMatch(t);
  if (trailY != null && daysBack == 0) {
    final rest = t.substring(0, trailY.start).trim();
    if (rest.isNotEmpty) {
      t = rest;
      daysBack = 1;
    }
  }
  final trailNight = _trailLastNight.firstMatch(t);
  if (trailNight != null) {
    final rest = t.substring(0, trailNight.start).trim();
    if (rest.isNotEmpty) {
      t = rest;
      if (daysBack == 0 && !_sleepStaysOnLogDay.hasMatch(rest)) daysBack = 1;
    }
  }
  if (hour == null) {
    final trail = _consumeTrail(t);
    if (trail != null) {
      t = trail.text;
      hour = trail.hour;
      minute = trail.minute;
    }
  }
  return StampedLine(text: t, hour: hour, minute: minute, daysBack: daysBack);
}

StampedLine? _consumeLead(String t) {
  final clock = _leadClock.firstMatch(t);
  if (clock != null) {
    var h = int.parse(clock.group(1)!);
    final min = int.parse(clock.group(2)!);
    final rest = t.substring(clock.end).trim();
    if (rest.isEmpty || h > 23 || min > 59) return null;
    final ap = clock.group(3)?.toLowerCase();
    if (ap != null) {
      if (h > 12 || h == 0) return null;
      h = _to24(h, ap);
    }
    return StampedLine(text: rest, hour: h, minute: min);
  }
  final ampm = _leadAmpm.firstMatch(t);
  if (ampm != null) {
    var h = int.parse(ampm.group(1)!);
    final rest = t.substring(ampm.end).trim();
    if (rest.isEmpty || h < 1 || h > 12) return null;
    return StampedLine(
      text: rest,
      hour: _to24(h, ampm.group(2)!.toLowerCase()),
      minute: 0,
    );
  }
  final noon = RegExp(
    r'^(?:at\s+)?noon\s+',
    caseSensitive: false,
  ).firstMatch(t);
  if (noon != null) {
    final rest = t.substring(noon.end).trim();
    if (rest.isNotEmpty) {
      return StampedLine(text: rest, hour: 12, minute: 0);
    }
  }
  final midnight = RegExp(
    r'^(?:at\s+)?midnight\s+',
    caseSensitive: false,
  ).firstMatch(t);
  if (midnight != null) {
    final rest = t.substring(midnight.end).trim();
    if (rest.isNotEmpty) {
      return StampedLine(text: rest, hour: 0, minute: 0);
    }
  }
  return _leadPeriod(t, 0);
}

const _periodHour = <String, int>{
  'morning': 8,
  'rano': 8,
  'afternoon': 15,
  'evening': 19,
  'wieczorem': 19,
  'tonight': 21,
  'breakfast': 8,
  'sniadanie': 8,
  'lunch': 13,
  'obiad': 13,
  'dinner': 19,
  'supper': 19,
  'kolacja': 19,
  'brunch': 11,
};

StampedLine? _leadPeriod(String t, int daysBack) {
  final f = foldLatin(t);
  if (f.length != t.length) return null;
  final po = RegExp(r'^po\s+poludniu\s+').firstMatch(f);
  if (po != null) {
    final rest = t.substring(po.end).trim();
    if (rest.isNotEmpty) {
      return StampedLine(text: rest, hour: 15, minute: 0, daysBack: daysBack);
    }
  }
  final period = RegExp(
    r'^(?:this\s+)?(morning|afternoon|evening|tonight|rano|wieczorem)\s+',
  ).firstMatch(f);
  if (period != null) {
    final rest = t.substring(period.end).trim();
    final hour = _periodHour[period.group(1)!];
    if (rest.isNotEmpty && hour != null) {
      return StampedLine(text: rest, hour: hour, minute: 0, daysBack: daysBack);
    }
  }
  final meal = RegExp(
    r'^(?:(?:for|na)\s+)?(breakfast|lunch|dinner|supper|brunch|sniadanie|obiad|kolacja)\s+',
  ).firstMatch(f);
  if (meal != null) {
    final rest = t.substring(meal.end).trim();
    final hour = _periodHour[meal.group(1)!];
    if (rest.isNotEmpty && hour != null) {
      return StampedLine(text: rest, hour: hour, minute: 0, daysBack: daysBack);
    }
  }
  return null;
}

StampedLine? _consumeTrail(String t) {
  final f = foldLatin(t);
  if (f.length != t.length) return null;
  StampedLine? cut(RegExpMatch m, int hour, [int minute = 0]) {
    final rest = t.substring(0, m.start).trim();
    if (rest.isEmpty) return null;
    return StampedLine(text: rest, hour: hour, minute: minute);
  }

  final clock = RegExp(
    r'\s+(?:(?:around|about|at|o)\s+)+(\d{1,2})[:.](\d{2})(?:\s*(am|pm))?\s*$',
    caseSensitive: false,
  ).firstMatch(t);
  if (clock != null) {
    var h = int.parse(clock.group(1)!);
    final min = int.parse(clock.group(2)!);
    if (h <= 23 && min <= 59) {
      final ap = clock.group(3)?.toLowerCase();
      if (ap != null) {
        if (h >= 1 && h <= 12) h = _to24(h, ap);
      }
      final hit = cut(clock, h, min);
      if (hit != null && !_sleepKeepsClock(hit.text)) return hit;
    }
  }
  final ampm = RegExp(
    r'\s+(?:(?:around|about|at|o)\s+)+(\d{1,2})\s*(am|pm)\s*$',
    caseSensitive: false,
  ).firstMatch(t);
  if (ampm != null) {
    var h = int.parse(ampm.group(1)!);
    if (h >= 1 && h <= 12) {
      final hit = cut(ampm, _to24(h, ampm.group(2)!.toLowerCase()));
      if (hit != null && !_sleepKeepsClock(hit.text)) return hit;
    }
  }
  final noon = RegExp(
    r'\s+(?:at\s+)?noon\s*$',
    caseSensitive: false,
  ).firstMatch(t);
  if (noon != null) {
    final hit = cut(noon, 12);
    if (hit != null) return hit;
  }
  final midnight = RegExp(
    r'\s+(?:at\s+)?midnight\s*$',
    caseSensitive: false,
  ).firstMatch(t);
  if (midnight != null) {
    final hit = cut(midnight, 0);
    if (hit != null) return hit;
  }
  final po = RegExp(r'\s+po\s+poludniu\s*$').firstMatch(f);
  if (po != null) {
    final hit = cut(po, 15);
    if (hit != null) return hit;
  }
  final period = RegExp(
    r'\s+(?:(?:this|in\s+the)\s+)?(morning|afternoon|evening|tonight|rano|wieczorem)\s*$',
  ).firstMatch(f);
  if (period != null) {
    final hour = _periodHour[period.group(1)!];
    if (hour != null) {
      final hit = cut(period, hour);
      if (hit != null) return hit;
    }
  }
  final meal = RegExp(
    r'\s+(?:for|na)\s+(breakfast|lunch|dinner|supper|brunch|sniadanie|obiad|kolacja)\s*$',
  ).firstMatch(f);
  if (meal != null) {
    final hour = _periodHour[meal.group(1)!];
    if (hour != null) {
      final hit = cut(meal, hour);
      if (hit != null) return hit;
    }
  }
  return null;
}

bool _sleepKeepsClock(String rest) {
  return RegExp(
    r'(?:went to (?:bed|sleep)|fell asleep|headed to bed|in bed|bedtime|lights out|woke(?:\s+up)?|got up|(?:was\s+)?up|poszedlem spac|poszlam spac|wstalem|wstalam|obudzilem|obudzilam)\s*$',
    caseSensitive: false,
  ).hasMatch(rest.trim());
}

int _to24(int hour, String ampm) {
  if (ampm == 'am') return hour == 12 ? 0 : hour;
  return hour == 12 ? 12 : hour + 12;
}

/// Put the clock back on the prose so REVERT can re-submit at the same hour.
String draftFromStamp({
  required DateTime at,
  required String text,
  DateTime? now,
}) {
  final clock = '${at.hour}:${at.minute.toString().padLeft(2, '0')} $text';
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  if (today.difference(day).inDays == 1) return 'yesterday $clock';
  return clock;
}
