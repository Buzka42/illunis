import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/records.dart';
import '../../core/state/app_providers.dart';
import '../../core/wearables/life_stats.dart';

/// A3 dashboard comparison model: comparison-ready evidence, plain data.
///
/// Honesty rules (enforced here, not in the UI):
/// - Every value is nullable; observed-zero and absence are distinct.
///   Absence renders as [Strings.emptyDash] ('—') downstream.
/// - Each day is resolved through [resolveLifeStats] (journal-wins-ties,
///   source priority) BEFORE aggregation. Journal + wearable figures for the
///   same metric are never summed.
/// - Missing days are never zero-filled: window means divide by the observed
///   count, never by 7.
/// - Mixed-source windows expose their composition ([sourceCounts]); callers
///   must never attach a single misleading source label.
/// - Percentages against a null or zero denominator are undefined (null),
///   never 0% / 100% / infinity.
/// - Sleep is hours only: durations plus the observed range. No bedtime
///   regularity claims, no timestamps.

/// One nullable figure with its unit, bounds, and provenance.
@immutable
class ComparedValue {
  const ComparedValue({
    required this.value,
    required this.unit,
    required this.source,
    this.lowerBound,
    this.upperBound,
  });

  /// Observed figure, or null when absent. An observed 0.0 stays 0.0.
  final double? value;
  final String unit;
  final StatSource? source;
  final double? lowerBound;
  final double? upperBound;

  bool get isPresent => value != null;
}

/// Same-day intake/burn pair on a shared scale.
///
/// Journal expenditure is a loggedSessions estimate, so a journal-sourced
/// burn is flagged [burnEstimated] honestly instead of presented as measured.
@immutable
class IntakeBurnPair {
  const IntakeBurnPair({
    required this.day,
    required this.intake,
    required this.burn,
    required this.burnEstimated,
    required this.pendingIntakeCount,
    required this.pendingBurnCount,
    required this.sharedScaleMax,
    required this.balanceKcal,
    required this.intakeShareOfBurn,
  });

  final String day;
  final ComparedValue intake;
  final ComparedValue burn;

  /// True when burn comes from the journal (estimate), false for measured
  /// wearable burn, null when burn is absent.
  final bool? burnEstimated;

  /// Unconfirmed (pending) estimates excluded from the figures.
  final int pendingIntakeCount;
  final int pendingBurnCount;

  bool get hasPending => pendingIntakeCount + pendingBurnCount > 0;

  /// Shared bar scale: max of the two observed values, null when both absent.
  final double? sharedScaleMax;

  /// intake − burn; null unless both are observed.
  final double? balanceKcal;

  /// intake / burn; null unless both observed and burn != 0.
  /// A zero or absent burn leaves this undefined — never 0% or ∞.
  final double? intakeShareOfBurn;
}

/// One 7-day movement window: mean of OBSERVED days only.
@immutable
class MovementWindow {
  const MovementWindow({
    required this.startDay,
    required this.endDay,
    required this.meanActiveMinutes,
    required this.observedCount,
    required this.windowDays,
    required this.sourceCounts,
  });

  final String startDay;
  final String endDay;

  /// Mean active minutes over observed days only; null when none observed.
  final double? meanActiveMinutes;

  /// Days with a resolved (non-null) active-minutes figure.
  final int observedCount;

  /// Window length in days (always 7; kept for coverage math).
  final int windowDays;

  /// Contributing sources, e.g. {journal: 4, wearable: 1}. Empty when none.
  final Map<StatSource, int> sourceCounts;

  /// Observed fraction 0..1.
  double get coverage => windowDays == 0 ? 0 : observedCount / windowDays;

  /// Coverage too thin for a directional verdict ([ MovementComparison]).
  bool get isThin => observedCount < 4;

  /// Single source label only when unanimous; null for mixed/empty windows.
  StatSource? get unanimousSource =>
      sourceCounts.length == 1 ? sourceCounts.keys.single : null;
}

/// Two adjacent 7-day movement windows ending on the selected day.
@immutable
class MovementComparison {
  const MovementComparison({required this.current, required this.previous});

  /// 7 days ending on the selected day (inclusive).
  final MovementWindow current;

  /// The 7 days immediately before [current].
  final MovementWindow previous;

  /// current − previous mean; null when either window is absent or thin.
  /// No directional verdict is offered on thin coverage.
  double? get deltaMean {
    if (current.meanActiveMinutes == null ||
        previous.meanActiveMinutes == null) {
      return null;
    }
    if (current.isThin || previous.isThin) return null;
    return current.meanActiveMinutes! - previous.meanActiveMinutes!;
  }

  bool get hasVerdict => deltaMean != null;
}

/// One night of sleep: duration hours only, no timestamps.
@immutable
class SleepNight {
  const SleepNight({required this.day, required this.hours, this.source});

  final String day;

  /// Sleep duration in hours; null when unobserved.
  final double? hours;
  final StatSource? source;

  bool get isPresent => hours != null;
}

/// 7-night sleep series ending on the selected day.
@immutable
class SleepSeries {
  const SleepSeries({required this.nights});

  final List<SleepNight> nights;

  List<SleepNight> get observed => nights.where((n) => n.isPresent).toList();

  int get observedCount => observed.length;

  /// Mean over observed nights only; null when none observed.
  double? get meanHours {
    final o = observed;
    if (o.isEmpty) return null;
    var sum = 0.0;
    for (final n in o) {
      sum += n.hours!;
    }
    return sum / o.length;
  }

  /// Min observed duration; null when none observed.
  double? get minHours {
    final o = observed;
    if (o.isEmpty) return null;
    var m = o.first.hours!;
    for (final n in o) {
      if (n.hours! < m) m = n.hours!;
    }
    return m;
  }

  /// Max observed duration; null when none observed.
  double? get maxHours {
    final o = observed;
    if (o.isEmpty) return null;
    var m = o.first.hours!;
    for (final n in o) {
      if (n.hours! > m) m = n.hours!;
    }
    return m;
  }

  /// Contributing sources over observed nights; empty when none.
  Map<StatSource, int> get sourceCounts {
    final counts = <StatSource, int>{};
    for (final n in observed) {
      final s = n.source;
      if (s != null) counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }
}

/// Comparison-ready evidence for one selected day.
@immutable
class DashboardComparisons {
  const DashboardComparisons({
    required this.selectedDay,
    required this.intakeBurn,
    required this.movement,
    required this.sleep,
  });

  final String selectedDay;
  final IntakeBurnPair intakeBurn;
  final MovementComparison movement;
  final SleepSeries sleep;
}

String _shiftDay(String day, int delta) {
  final d = dayKeyDate(day);
  return dayKey(DateTime(d.year, d.month, d.day + delta));
}

/// Pure builder. Each [DailyLifeStats] must already be resolved per day via
/// [resolveLifeStats] (source priority applied BEFORE aggregation).
///
/// [dayStats] maps day keys to that day's resolved stats; missing keys count
/// as absent days (never zero-filled).
DashboardComparisons buildDashboardComparisons({
  required String selectedDay,
  required Map<String, DailyLifeStats> dayStats,
  int pendingIntakeCount = 0,
  int pendingBurnCount = 0,
}) {
  final selected = dayStats[selectedDay];

  final intakeVal = selected?.calorieIntake.value;
  final burnVal = selected?.caloriesBurned.value;
  final burnSource = burnVal == null ? null : selected?.caloriesBurned.source;

  double? sharedMax;
  if (intakeVal != null || burnVal != null) {
    sharedMax = [
      ?intakeVal,
      ?burnVal,
    ].reduce((a, b) => a > b ? a : b);
    if (sharedMax <= 0) sharedMax = null;
  }

  final intakeBurn = IntakeBurnPair(
    day: selectedDay,
    intake: ComparedValue(
      value: intakeVal,
      unit: 'kcal',
      source: intakeVal == null ? null : selected?.calorieIntake.source,
      lowerBound: 0,
    ),
    burn: ComparedValue(
      value: burnVal,
      unit: 'kcal',
      source: burnSource,
      lowerBound: 0,
    ),
    burnEstimated: burnVal == null
        ? null
        : burnSource == StatSource.journal,
    pendingIntakeCount: pendingIntakeCount,
    pendingBurnCount: pendingBurnCount,
    sharedScaleMax: sharedMax,
    balanceKcal: intakeVal != null && burnVal != null
        ? intakeVal - burnVal
        : null,
    intakeShareOfBurn: intakeVal != null && burnVal != null && burnVal != 0
        ? intakeVal / burnVal
        : null,
  );

  MovementWindow window(int endOffset, int length) {
    final end = _shiftDay(selectedDay, endOffset);
    final start = _shiftDay(selectedDay, endOffset - length + 1);
    var sum = 0.0;
    var observed = 0;
    final sources = <StatSource, int>{};
    for (var i = 0; i < length; i++) {
      final stats = dayStats[_shiftDay(selectedDay, endOffset - length + 1 + i)];
      final v = stats?.activeMinutes.value;
      if (v != null) {
        sum += v;
        observed++;
        final s = stats!.activeMinutes.source;
        sources[s] = (sources[s] ?? 0) + 1;
      }
    }
    return MovementWindow(
      startDay: start,
      endDay: end,
      meanActiveMinutes: observed == 0 ? null : sum / observed,
      observedCount: observed,
      windowDays: length,
      sourceCounts: sources,
    );
  }

  final movement = MovementComparison(
    current: window(0, 7),
    previous: window(-7, 7),
  );

  final nights = <SleepNight>[
    for (var i = -6; i <= 0; i++)
      SleepNight(
        day: _shiftDay(selectedDay, i),
        hours: dayStats[_shiftDay(selectedDay, i)]?.sleep.value,
        source: dayStats[_shiftDay(selectedDay, i)]?.sleep.value == null
            ? null
            : dayStats[_shiftDay(selectedDay, i)]?.sleep.source,
      ),
  ];

  return DashboardComparisons(
    selectedDay: selectedDay,
    intakeBurn: intakeBurn,
    movement: movement,
    sleep: SleepSeries(nights: nights),
  );
}

/// Provider wiring: resolves each day through [lifeStatsProvider] (the
/// existing source-priority logic) before aggregation, then builds the
/// comparison model. Pending counts come from unconfirmed journal estimates.
final dashboardComparisonsProvider =
    Provider.family<DashboardComparisons, String>((ref, day) {
  final days = <String, DailyLifeStats>{
    for (var i = -13; i <= 0; i++) _shiftDay(day, i): ref.watch(
      lifeStatsProvider(_shiftDay(day, i)),
    ),
  };
  final figures = ref.watch(journalFiguresProvider);
  final sameDayFigures = figures.day == day;
  return buildDashboardComparisons(
    selectedDay: day,
    dayStats: days,
    pendingIntakeCount:
        sameDayFigures ? figures.unconfirmed.length : 0,
    pendingBurnCount:
        sameDayFigures ? figures.unconfirmedActs.length : 0,
  );
});
