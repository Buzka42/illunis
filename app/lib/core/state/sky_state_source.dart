import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sky/celestial_math.dart';
import '../sky/sky_state.dart';

/// Whoever produces the sky's input implements this. Phase 1 has mocks;
/// Phase 3 has rollups from a wearable. The sky cannot tell the difference,
/// which is the point.
abstract class SkyStateSource {
  Stream<SkyState> get states;
  Future<void> dispose();
}

/// Real clock, real calendar, real moon phase, fixed observer, mock vitals.
class LiveMockSource implements SkyStateSource {
  LiveMockSource({
    this.latitudeDeg = 52.23,
    this.vitals = const MockVitals.typical(),
    Duration period = const Duration(seconds: 1),
  }) {
    _controller = StreamController<SkyState>.broadcast(
      onListen: () {
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
  late final StreamController<SkyState> _controller;
  Timer? _timer;

  @override
  Stream<SkyState> get states => _controller.stream;

  void _emit() {
    final now = DateTime.now();
    _controller.add(stateFor(now));
  }

  SkyState stateFor(DateTime now) => stateAt(now, latitudeDeg, vitals);

  static SkyState stateAt(DateTime now, double latitudeDeg, MockVitals vitals) {
    final midnight = DateTime(now.year, now.month, now.day);
    final t = now.difference(midnight).inMilliseconds / 86400000.0;
    final dayOfYear = now.difference(DateTime(now.year)).inHours / 24.0 + 1;
    return SkyState(
      timeOfDay: t,
      dayOfYear: dayOfYear,
      latitudeDeg: latitudeDeg,
      moonPhase: moonPhaseFor(now.toUtc()),
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

/// Manual overrides for the debug sheet. Null means "follow the source".
@immutable
class SkyOverrides {
  const SkyOverrides({
    this.timeOfDay,
    this.dayOfYear,
    this.latitudeDeg,
    this.moonPhase,
    this.preset = SkyPreset.live,
  });

  final double? timeOfDay, dayOfYear, latitudeDeg, moonPhase;
  final SkyPreset preset;

  bool get any =>
      timeOfDay != null ||
      dayOfYear != null ||
      latitudeDeg != null ||
      moonPhase != null;

  SkyOverrides copyWith({
    Object? timeOfDay = _unset,
    Object? dayOfYear = _unset,
    Object? latitudeDeg = _unset,
    Object? moonPhase = _unset,
    SkyPreset? preset,
  }) => SkyOverrides(
    timeOfDay: timeOfDay == _unset ? this.timeOfDay : timeOfDay as double?,
    dayOfYear: dayOfYear == _unset ? this.dayOfYear : dayOfYear as double?,
    latitudeDeg: latitudeDeg == _unset
        ? this.latitudeDeg
        : latitudeDeg as double?,
    moonPhase: moonPhase == _unset ? this.moonPhase : moonPhase as double?,
    preset: preset ?? this.preset,
  );

  SkyState apply(SkyState s) {
    final v = preset.vitals;
    return s.copyWith(
      timeOfDay: timeOfDay,
      dayOfYear: dayOfYear,
      latitudeDeg: latitudeDeg,
      moonPhase: moonPhase,
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
  final raw =
      ref.watch(_rawSkyStateProvider).value ??
      LiveMockSource.stateAt(DateTime.now(), 52.23, const MockVitals.typical());
  return ref.watch(skyOverridesProvider).apply(raw);
});
