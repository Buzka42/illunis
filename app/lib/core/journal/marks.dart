import '../db/store.dart';

/// Civil-day fraction of a timestamp. The timeline is one turn of the clock.
double timeOfDayFraction(DateTime at) {
  final millis =
      (at.hour * 3600 + at.minute * 60 + at.second) * 1000 + at.millisecond;
  return (millis / 86400000.0).clamp(0.0, 1.0);
}

/// One hairline per journal page on [day], in clock order. Kind is not
/// drawn — the track is a scale, not a legend.
List<double> timelineMarksOn(AppStore store, String day) {
  final marks = <double>[
    for (final e in store.journal)
      if (e.day == day) timeOfDayFraction(e.at),
  ]..sort();
  return marks;
}
