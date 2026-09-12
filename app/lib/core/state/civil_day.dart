import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sky_state_source.dart';

/// Injectable device civil clock, independent of debug sky scrubbing.
final civilClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

DateTime civilDate(DateTime at) => DateTime(at.year, at.month, at.day);

final _dayTicksProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(civilClockProvider);
  return ref
      .watch(skyStateSourceProvider)
      .states
      .map((_) => civilDate(clock()))
      .distinct();
});

/// Source lifecycle controls ticking; the first resumed emission catches up.
final civilDayProvider = Provider<DateTime>(
  (ref) =>
      ref.watch(_dayTicksProvider).value ??
      civilDate(ref.watch(civilClockProvider)()),
);
