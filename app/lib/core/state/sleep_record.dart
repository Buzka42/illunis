import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'sky_state_source.dart';

enum SleepStage { awake, light, deep, rem }

/// One stretch of one stage. Hours are relative to the *displayed* day's
/// midnight, so last night's 23:10 is `-0.83` and this morning's 06:46 is
/// `6.77`. The timeline folds negatives onto the right end of the track.
@immutable
class SleepSegment {
  const SleepSegment(this.startHours, this.endHours, this.stage);
  final double startHours;
  final double endHours;
  final SleepStage stage;
}

@immutable
class SleepRecord {
  const SleepRecord({
    required this.startHours,
    required this.endHours,
    this.segments = const [],
  });

  final double startHours;
  final double endHours;

  /// Stage breakdown when the source has one; empty means duration only.
  final List<SleepSegment> segments;

  double get durationHours => endHours - startHours;

  /// Time asleep excluding awake segments; the whole window if unstaged.
  double get asleepHours => segments.isEmpty
      ? durationHours
      : segments
            .where((s) => s.stage != SleepStage.awake)
            .fold(0.0, (a, s) => a + (s.endHours - s.startHours));

  /// A plausible night: ~90-minute cycles, deep early, REM late, brief wakes.
  factory SleepRecord.mock({
    required double startHours,
    required double endHours,
    int seed = 7,
    double restlessness = 0.15,
  }) {
    final rng = math.Random(seed);
    final segs = <SleepSegment>[];
    var t = startHours;
    var cycle = 0;
    // Falling asleep: a short awake, then light.
    void add(double len, SleepStage s) {
      if (t + len > endHours) len = endHours - t;
      if (len <= 0) return;
      segs.add(SleepSegment(t, t + len, s));
      t += len;
    }

    add(0.12 + restlessness * 0.3, SleepStage.awake);
    while (t < endHours - 0.01) {
      final late = cycle / 5.0; // 0 early night .. 1 morning
      add(0.20 + rng.nextDouble() * 0.15, SleepStage.light);
      add(
        (0.75 - 0.55 * late).clamp(0.1, 0.8) * (0.85 + rng.nextDouble() * 0.3),
        SleepStage.deep,
      );
      add(0.15 + rng.nextDouble() * 0.15, SleepStage.light);
      add(
        (0.20 + 0.45 * late) * (0.85 + rng.nextDouble() * 0.3),
        SleepStage.rem,
      );
      if (rng.nextDouble() < 0.35 + restlessness) {
        add(
          0.04 + rng.nextDouble() * 0.12 * (1 + restlessness * 3),
          SleepStage.awake,
        );
      }
      cycle++;
    }
    return SleepRecord(
      startHours: startHours,
      endHours: endHours,
      segments: segs,
    );
  }
}

/// Last night, as the source knows it. Debug presets still inject a staged
/// mock; live mode reads the journal's last sleep, or nothing.
final sleepRecordProvider = Provider<SleepRecord?>((ref) {
  final preset = ref.watch(skyOverridesProvider.select((o) => o.preset));
  if (preset != SkyPreset.live) {
    return switch (preset) {
      SkyPreset.noData => null,
      SkyPreset.overreached => SleepRecord.mock(
        startHours: 1.35,
        endHours: 6.1,
        seed: 3,
        restlessness: 0.45,
      ),
      SkyPreset.restedMorning => SleepRecord.mock(
        startHours: -1.5,
        endHours: 6.9,
        seed: 11,
        restlessness: 0.05,
      ),
      _ => SleepRecord.mock(startHours: -0.83, endHours: 6.77),
    };
  }
  ref.watch(storeRevisionProvider);
  final s = ref.watch(todayFiguresProvider).sleep;
  if (s == null) return null;
  return SleepRecord(startHours: s.startHours, endHours: s.endHours);
});
