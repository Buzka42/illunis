import '../i18n/fold.dart';

/// A leading clock on a journal line is the time of the page, not prose.
///
/// `7:30 ran 5k` and `at 8am ate oatmeal` stamp the entry; the prefix is
/// stripped so the list does not show the hour twice. Bare `7h` and a
/// duration like `in 24:30` are left alone. A leading `yesterday` moves
/// the page back one civil day. `this morning` / `for lunch` without a
/// clock sit at a civil hour so the list is not all "logged at 22:00".
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

final _leadClock = RegExp(
  r'^(?:(?:this\s+)?(?:morning|afternoon|evening|tonight)\s+)?(?:at\s+)?(\d{1,2})[:.](\d{2})(?:\s*(am|pm))?\s+',
  caseSensitive: false,
);

final _leadAmpm = RegExp(
  r'^(?:(?:this\s+)?(?:morning|afternoon|evening|tonight)\s+)?(?:at\s+)?(\d{1,2})\s*(am|pm)\b\s+',
  caseSensitive: false,
);

StampedLine stampJournalLine(String raw) {
  var t = raw.trim();
  var daysBack = 0;
  final y = _leadYesterday.firstMatch(t);
  if (y != null) {
    final rest = t.substring(y.end).trim();
    if (rest.isNotEmpty) {
      t = rest;
      daysBack = 1;
    }
  }
  final clock = _leadClock.firstMatch(t);
  if (clock != null) {
    var h = int.parse(clock.group(1)!);
    final min = int.parse(clock.group(2)!);
    final rest = t.substring(clock.end).trim();
    if (rest.isEmpty || h > 23 || min > 59) {
      return StampedLine(text: t, daysBack: daysBack);
    }
    final ap = clock.group(3)?.toLowerCase();
    if (ap != null) {
      if (h > 12 || h == 0) return StampedLine(text: t, daysBack: daysBack);
      h = _to24(h, ap);
    }
    return StampedLine(text: rest, hour: h, minute: min, daysBack: daysBack);
  }
  final ampm = _leadAmpm.firstMatch(t);
  if (ampm != null) {
    var h = int.parse(ampm.group(1)!);
    final rest = t.substring(ampm.end).trim();
    if (rest.isEmpty || h < 1 || h > 12) {
      return StampedLine(text: t, daysBack: daysBack);
    }
    h = _to24(h, ampm.group(2)!.toLowerCase());
    return StampedLine(text: rest, hour: h, minute: 0, daysBack: daysBack);
  }
  final noon = RegExp(
    r'^(?:at\s+)?noon\s+',
    caseSensitive: false,
  ).firstMatch(t);
  if (noon != null) {
    final rest = t.substring(noon.end).trim();
    if (rest.isNotEmpty) {
      return StampedLine(text: rest, hour: 12, minute: 0, daysBack: daysBack);
    }
  }
  final midnight = RegExp(
    r'^(?:at\s+)?midnight\s+',
    caseSensitive: false,
  ).firstMatch(t);
  if (midnight != null) {
    final rest = t.substring(midnight.end).trim();
    if (rest.isNotEmpty) {
      return StampedLine(text: rest, hour: 0, minute: 0, daysBack: daysBack);
    }
  }
  return _leadPeriod(t, daysBack) ?? StampedLine(text: t, daysBack: daysBack);
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
    r'^(?:for\s+)?(breakfast|lunch|dinner|supper|brunch|sniadanie|obiad|kolacja)\s+',
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
