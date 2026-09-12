import 'dart:async';

import '../db/records.dart';
import '../db/store.dart';
import '../sky/celestial_math.dart';
import '../sky/sky_state.dart';
import '../state/sky_state_source.dart';
import '../weather/weather_service.dart';

/// Clock plus daily rollups. Vitals are null until the record can support
/// them. Debug presets still overlay through [SkyOverrides].
class LocalSkyStateSource implements SkyStateSource {
  LocalSkyStateSource(
    this.store, {
    this.weatherService,
    DateTime Function()? clock,
    this.period = const Duration(seconds: 1),
  }) : _clock = clock ?? DateTime.now {
    _controller = StreamController<SkyState>.broadcast(
      onListen: () {
        if (_suspended) return;
        _emit();
        _timer = Timer.periodic(period, (_) => _emit());
      },
      onCancel: () => _timer?.cancel(),
    );
    store.addListener(_emit);
    weatherService?.addListener(_emit);
  }

  final AppStore store;
  final WeatherService? weatherService;
  final DateTime Function() _clock;
  final Duration period;
  late final StreamController<SkyState> _controller;
  Timer? _timer;
  bool _suspended = false;

  @override
  Stream<SkyState> get states => _controller.stream;

  @override
  void setSuspended(bool suspended) {
    _suspended = suspended;
    if (suspended) {
      _timer?.cancel();
      _timer = null;
    } else if (_controller.hasListener && _timer == null) {
      _emit();
      _timer = Timer.periodic(period, (_) => _emit());
    }
  }

  void _emit() {
    if (_suspended || _controller.isClosed) return;
    _controller.add(snapshot());
  }

  SkyState snapshot() => stateAt(
    _clock(),
    store,
    weather:
        store.profile.weatherSource != 'off' &&
            (weatherService?.matchesLocation(
                  store.profile.latitudeDeg,
                  store.profile.longitudeDeg,
                ) ??
                false)
        ? weatherService?.currentSkyWeather
        : null,
  );

  @override
  SkyState peek() => snapshot();

  static SkyState stateAt(DateTime now, AppStore store, {SkyWeather? weather}) {
    final t = civilDayFraction(now);
    final dayOfYear = civilDayOfYear(now);
    final summary = store.summaryOn(dayKey(now));
    return SkyState(
      timeOfDay: t,
      dayOfYear: dayOfYear,
      epochDays: civilMidnightEpoch(now),
      latitudeDeg: store.profile.latitudeDeg,
      moonPhase: moonPhaseFor(now.toUtc()),
      solarNoon: civilSolarNoon(now, store.profile.longitudeDeg),
      sleepScore: summary?.sleepScore,
      recovery: summary?.recovery,
      strain: summary?.strain,
      energyBalance: summary?.energyBalance,
      weather: weather,
    );
  }

  @override
  Future<void> dispose() async {
    store.removeListener(_emit);
    weatherService?.removeListener(_emit);
    _timer?.cancel();
    await _controller.close();
  }
}

/// Longitude, zone offset and the equation of time, folded into the
/// fraction of the civil day when the sun transits.
double civilSolarNoon(DateTime now, double longitudeDeg) {
  return solarNoonFor(
    civilMidnightEpoch(now) + civilDayFraction(now),
    longitudeDeg,
    now.timeZoneOffset.inMinutes / 60.0,
  );
}
