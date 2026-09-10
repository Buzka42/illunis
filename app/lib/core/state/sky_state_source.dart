import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sky/celestial_math.dart';
import '../sky/sky_state.dart';

/// Whoever produces the sky's input implements this. Production uses
/// `LocalSkyStateSource` (clock + rollups). Debug presets still overlay.
abstract class SkyStateSource {
  Stream<SkyState> get states;
  SkyState peek();
  Future<void> dispose();

  /// Pause/resume periodic emissions (app lifecycle). Default is a no-op so
  /// future sources stay backward compatible.
  void setSuspended(bool suspended) {}
}

/// Real clock, real calendar, real moon phase, fixed observer, mock vitals.
class LiveMockSource implements SkyStateSource {
  LiveMockSource({
    this.latitudeDeg = 52.23,
    this.vitals = const MockVitals.none(),
    this.period = const Duration(seconds: 1),
  }) {
    _controller = StreamController<SkyState>.broadcast(
      onListen: () {
        if (_suspended) return;
        _emit();
        _timer = Timer.periodic(period, (_) => _emit());
      },
      onCancel: () {
        _timer?.cancel();
      },
    );
  }

  final double latitudeDeg;
  final MockVitals vitals;
  final Duration period;
  late final StreamController<SkyState> _controller;
  Timer? _timer;
  bool _suspended = false;

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

  @override
  Stream<SkyState> get states => _controller.stream;

  void _emit() {
    final now = DateTime.now();
    _controller.add(stateFor(now));
  }

  SkyState stateFor(DateTime now) => stateAt(now, latitudeDeg, vitals);

  @override
  SkyState peek() => stateFor(DateTime.now());

  static SkyState stateAt(DateTime now, double latitudeDeg, MockVitals vitals) {
    final t = civilDayFraction(now);
    final dayOfYear = civilDayOfYear(now);
    return SkyState(
      timeOfDay: t,
      dayOfYear: dayOfYear,
      epochDays: civilMidnightEpoch(now),
      latitudeDeg: latitudeDeg,
      moonPhase: moonPhaseFor(now.toUtc()),
      solarNoon: solarNoonFor(
        civilMidnightEpoch(now) + t,
        21.01,
        now.timeZoneOffset.inMinutes / 60.0,
      ),
      sleepScore: vitals.sleepScore,
      recovery: vitals.recovery,
      strain: vitals.strain,
      energyBalance: vitals.energyBalance,
    );
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}

@immutable
class MockVitals {
  const MockVitals({
    this.sleepScore,
    this.recovery,
    this.strain,
    this.energyBalance,
  });
  const MockVitals.typical()
    : sleepScore = 0.81,
      recovery = 0.74,
      strain = 0.42,
      energyBalance = 0.18;
  const MockVitals.none()
    : sleepScore = null,
      recovery = null,
      strain = null,
      energyBalance = null;

  final double? sleepScore, recovery, strain, energyBalance;
}

/// Named scenarios. They are the design's test cases as much as the code's.
enum SkyPreset {
  live('Live'),
  restedMorning('Rested morning'),
  overreached('Overreached'),
  surplusWeek('Surplus week'),
  deficitWeek('Deficit week'),
  noData('No data');

  const SkyPreset(this.label);
  final String label;

  MockVitals get vitals => switch (this) {
    live => const MockVitals.typical(),
    restedMorning => const MockVitals(
      sleepScore: 0.92,
      recovery: 0.86,
      strain: 0.10,
      energyBalance: 0.0,
    ),
    overreached => const MockVitals(
      sleepScore: 0.38,
      recovery: 0.28,
      strain: 0.92,
      energyBalance: -0.4,
    ),
    surplusWeek => const MockVitals(
      sleepScore: 0.72,
      recovery: 0.62,
      strain: 0.30,
      energyBalance: 0.8,
    ),
    deficitWeek => const MockVitals(
      sleepScore: 0.60,
      recovery: 0.50,
      strain: 0.62,
      energyBalance: -0.8,
    ),
    noData => const MockVitals.none(),
  };
}

/// Wall-clock fractions do not gain/lose an hour on DST transition days.
double civilDayFraction(DateTime date) =>
    (date.hour * 3600 +
        date.minute * 60 +
        date.second +
        date.millisecond / 1000) /
    86400;

double civilDayOfYear(DateTime date) =>
    DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(date.year)).inDays +
    1.0;

/// Epoch basis using the offset at the represented instant. Adding the
/// wall-clock fraction reconstructs UTC even on a daylight-saving boundary.
double civilMidnightEpoch(DateTime date) =>
    epochDaysForDate(date.year, date.month, date.day) -
    date.timeZoneOffset.inSeconds / 86400.0;

/// Simulated observations for debug review. Product sources bypass this
/// enum and supply SkyState.weather directly.
enum WeatherPreset {
  source('Source', null),
  clear('Clear', SkyWeather.clear()),
  cloudy('Cloudy', SkyWeather(cloudCoverage: 0.58, cumulus: 0.9)),
  cirrus('Cirrus', SkyWeather(cloudCoverage: 0.45, cumulus: 0, cirrus: 1)),
  overcast('Overcast', SkyWeather(cloudCoverage: 1, cumulus: 0.12)),
  rain(
    'Rain',
    SkyWeather(cloudCoverage: 0.96, cumulus: 0.3, rain: 0.8, fog: 0.18),
  ),
  fog('Fog', SkyWeather(cloudCoverage: 0.18, cumulus: 0.05, fog: 0.9)),
  snow(
    'Snow',
    SkyWeather(cloudCoverage: 0.92, cumulus: 0.2, snow: 0.8, fog: 0.16),
  );

  const WeatherPreset(this.label, this.weather);
  final String label;
  final SkyWeather? weather;
}

/// Manual overrides for the debug sheet. Null means "follow the source".
@immutable
class SkyOverrides {
  const SkyOverrides({
    this.timeOfDay,
    this.dayOfYear,
    this.latitudeDeg,
    this.moonPhase,
    this.preset = SkyPreset.live,
    this.weatherPreset = WeatherPreset.source,
    this.weather,
  });

  final double? timeOfDay, dayOfYear, latitudeDeg, moonPhase;
  final SkyPreset preset;
  final WeatherPreset weatherPreset;
  final SkyWeather? weather;

  bool get any =>
      timeOfDay != null ||
      dayOfYear != null ||
      latitudeDeg != null ||
      moonPhase != null ||
      weatherPreset != WeatherPreset.source ||
      weather != null;

  SkyOverrides copyWith({
    Object? timeOfDay = _unset,
    Object? dayOfYear = _unset,
    Object? latitudeDeg = _unset,
    Object? moonPhase = _unset,
    SkyPreset? preset,
    WeatherPreset? weatherPreset,
    Object? weather = _unset,
  }) => SkyOverrides(
    timeOfDay: timeOfDay == _unset ? this.timeOfDay : timeOfDay as double?,
    dayOfYear: dayOfYear == _unset ? this.dayOfYear : dayOfYear as double?,
    latitudeDeg: latitudeDeg == _unset
        ? this.latitudeDeg
        : latitudeDeg as double?,
    moonPhase: moonPhase == _unset ? this.moonPhase : moonPhase as double?,
    preset: preset ?? this.preset,
    weatherPreset: weatherPreset ?? this.weatherPreset,
    weather: weather == _unset ? this.weather : weather as SkyWeather?,
  );

  SkyState apply(SkyState s) {
    final v = preset.vitals;
    final sourceEpoch = s.epochDays + s.timeOfDay;
    final targetEpoch =
        s.epochDays +
        ((dayOfYear ?? s.dayOfYear) - s.dayOfYear) +
        (timeOfDay ?? s.timeOfDay);
    final moved = timeOfDay != null || dayOfYear != null;
    final phase =
        moonPhase ??
        (moved
            ? (s.moonPhase +
                      moonPhaseAt(targetEpoch) -
                      moonPhaseAt(sourceEpoch)) %
                  1
            : s.moonPhase);
    return s.copyWith(
      timeOfDay: timeOfDay,
      dayOfYear: dayOfYear,
      latitudeDeg: latitudeDeg,
      moonPhase: phase,
      solarNoon: moved
          ? (s.solarNoon -
                    (equationOfTimeMinutes(targetEpoch) -
                            equationOfTimeMinutes(sourceEpoch)) /
                        1440) %
                1
          : s.solarNoon,
      weather: kDebugMode
          ? weather ??
                (weatherPreset == WeatherPreset.source
                    ? s.weather
                    : weatherPreset.weather)
          : s.weather,
      sleepScore: preset == SkyPreset.live ? s.sleepScore : v.sleepScore,
      recovery: preset == SkyPreset.live ? s.recovery : v.recovery,
      strain: preset == SkyPreset.live ? s.strain : v.strain,
      energyBalance: preset == SkyPreset.live
          ? s.energyBalance
          : v.energyBalance,
    );
  }
}

const _unset = Object();

/// The one source the app is wired to. Swap the override to plug in a
/// real one; nothing downstream changes.
final skyStateSourceProvider = Provider<SkyStateSource>((ref) {
  final source = LiveMockSource();
  ref.onDispose(source.dispose);
  return source;
});

final skyOverridesProvider =
    NotifierProvider<SkyOverridesNotifier, SkyOverrides>(
      SkyOverridesNotifier.new,
    );

class SkyOverridesNotifier extends Notifier<SkyOverrides> {
  @override
  SkyOverrides build() => const SkyOverrides();

  void set(SkyOverrides o) => state = o;
  void reset() => state = const SkyOverrides();
}

final _rawSkyStateProvider = StreamProvider<SkyState>((ref) {
  return ref.watch(skyStateSourceProvider).states;
});

/// What the sky renders. Source, then overrides, then out. Before the first
/// emission it is the source's idea of "now", so the sky never waits.
final skyStateProvider = Provider<SkyState>((ref) {
  final source = ref.watch(skyStateSourceProvider);
  final raw = ref.watch(_rawSkyStateProvider).value ?? source.peek();
  return ref.watch(skyOverridesProvider).apply(raw);
});
