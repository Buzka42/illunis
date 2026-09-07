import 'dart:async';
import 'dart:math' as math;

import '../db/records.dart';
import '../db/store.dart';
import '../sky/celestial_math.dart';
import '../sky/sky_state.dart';
import '../state/sky_state_source.dart';

/// Clock plus daily rollups. Vitals are null until the record can support
/// them. Debug presets still overlay through [SkyOverrides].
class LocalSkyStateSource implements SkyStateSource {
  LocalSkyStateSource(
    this.store, {
    DateTime Function()? clock,
    Duration period = const Duration(seconds: 1),
  }) : _clock = clock ?? DateTime.now {
    _controller = StreamController<SkyState>.broadcast(
      onListen: () {
        _emit();
        _timer = Timer.periodic(period, (_) => _emit());
      },
      onCancel: () => _timer?.cancel(),
    );
    store.addListener(_emit);
  }

  final AppStore store;
  final DateTime Function() _clock;
  late final StreamController<SkyState> _controller;
  Timer? _timer;

  @override
  Stream<SkyState> get states => _controller.stream;

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(snapshot());
  }

  SkyState snapshot() => stateAt(_clock(), store);

  @override
  SkyState peek() => snapshot();

  static SkyState stateAt(DateTime now, AppStore store) {
    final midnight = DateTime(now.year, now.month, now.day);
    final t = now.difference(midnight).inMilliseconds / 86400000.0;
    final dayOfYear = now.difference(DateTime(now.year)).inHours / 24.0 + 1;
    final summary = store.summaryOn(dayKey(now));
    return SkyState(
      timeOfDay: t,
      dayOfYear: dayOfYear,
      epochDays: epochDaysForDate(now.year, now.month, now.day),
      latitudeDeg: store.profile.latitudeDeg,
      moonPhase: moonPhaseFor(now.toUtc()),
      solarNoon: civilSolarNoon(now, store.profile.longitudeDeg),
      sleepScore: summary?.sleepScore,
      recovery: summary?.recovery,
      strain: summary?.strain,
      energyBalance: summary?.energyBalance,
    );
  }

  @override
  Future<void> dispose() async {
    store.removeListener(_emit);
    _timer?.cancel();
    await _controller.close();
  }
}

/// Longitude, zone offset and the equation of time, folded into the
/// fraction of the civil day when the sun transits.
double civilSolarNoon(DateTime now, double longitudeDeg) {
  final start = DateTime(now.year);
  final dayOfYear = now.difference(start).inMilliseconds / 86400000.0 + 1;
  final b = 2 * math.pi * (dayOfYear - 81) / 364;
  final eotMin =
      9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
  final tzHours = now.timeZoneOffset.inMinutes / 60.0;
  final offsetDays = ((tzHours * 15) - longitudeDeg) / 360.0 + eotMin / 1440.0;
  var noon = 0.5 + offsetDays;
  noon -= noon.floorToDouble();
  return noon;
}
