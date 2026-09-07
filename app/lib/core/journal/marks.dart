import '../db/store.dart';

/// Civil-day fraction of a timestamp. The timeline is one turn of the clock.
double timeOfDayFraction(DateTime at) {
  final midnight = DateTime(at.year, at.month, at.day);
  return at.difference(midnight).inMilliseconds / 86400000.0;
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
