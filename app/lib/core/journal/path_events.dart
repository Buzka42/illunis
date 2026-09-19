import 'package:flutter/foundation.dart';

import '../db/records.dart';
import '../db/store.dart';
import '../sky/path_event_geometry.dart';
import '../wearables/wearable_data.dart';

/// Semantic kind of path event.
enum PathEventKind {
  intake,
  burn,
  sleep,
}

/// The basis of an event's timestamp.
///
/// Honesty invariant: marks logged at entry time are labeled as [logAnchored],
/// indicating that the timestamp represents when the note was recorded, NOT
/// an independently measured or physically verified event time.
enum PathTimestampBasis {
  /// Anchored to the journal entry logging time.
  logAnchored,

  /// Independently observed or instrumented instant (e.g. wearable session start).
  observed,
}

/// Data provenance for the event.
enum PathEventProvenance {
  journal,
  healthConnect,
  wearable,
  manual,
  parsed;

  static PathEventProvenance fromSource(String source) {
    final s = source.toLowerCase();
    if (s == 'journal') return PathEventProvenance.journal;
    if (s == 'health-connect' || s == 'health_connect' || s == 'hc') {
      return PathEventProvenance.healthConnect;
    }
    if (s == 'wearable' || s == 'bridge' || s == 'pedometer' || s == 'phone') {
      return PathEventProvenance.wearable;
    }
    if (s == 'manual') return PathEventProvenance.manual;
    return PathEventProvenance.parsed;
  }
}

/// Computes local civil day fraction 0.0 .. 1.0 from a [DateTime].
double timeOfDayFractionFrom(DateTime dt) {
  final millis =
      (dt.hour * 3600 + dt.minute * 60 + dt.second) * 1000 + dt.millisecond;
  return (millis / 86400000.0).clamp(0.0, 1.0);
}

/// A confirmed event resolved from stored records for representation along
/// the sky's celestial path.
///
/// Extends [SkyPathEvent] to seamlessly bridge domain health records with pure
/// celestial geometry without violating layer separation.
///
/// Every field is grounded in stored ground truth:
/// - [timestampBasis] discloses whether the mark is [PathTimestampBasis.logAnchored].
/// - [duration] is strictly null when unknown — length is NEVER invented.
/// - Daily aggregates without timestamps (e.g. daily HC totals) cannot produce
///   timed path events.
@immutable
class PathEvent extends SkyPathEvent {
  PathEvent({
    required this.recordId,
    required this.civilDay,
    required this.kind,
    required this.timestamp,
    required this.timestampBasis,
    this.duration,
    this.kcal,
    required this.provenance,
    super.label,
  }) : super(
         id: recordId,
         timeOfDay: timeOfDayFractionFrom(timestamp),
         durationFraction: duration != null
             ? duration.inMicroseconds / 86400000000.0
             : null,
         energy: kcal,
         isIntake: kind == PathEventKind.intake,
         isLogAnchored: timestampBasis == PathTimestampBasis.logAnchored,
       );

  /// Unique ID of the underlying confirmed record (e.g. NutritionEntry.id).
  final String recordId;

  /// Civil day `yyyy-MM-dd`.
  final String civilDay;

  /// Kind of event: intake, burn, or sleep.
  final PathEventKind kind;

  /// The timestamp on this civil day.
  final DateTime timestamp;

  /// Whether the timestamp is log-anchored or independently observed.
  final PathTimestampBasis timestampBasis;

  /// Known duration of the event. Null if instantaneous or unknown.
  /// NEVER invented for unknown lengths.
  final Duration? duration;

  /// Energy in kilocalories, positive and finite, or null if unmeasured.
  final double? kcal;

  /// Origin / provenance of this event.
  final PathEventProvenance provenance;

  /// Fraction of the civil day, 0.0 .. 1.0.
  double get timeOfDayFraction => timeOfDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathEvent &&
          runtimeType == other.runtimeType &&
          recordId == other.recordId &&
          civilDay == other.civilDay &&
          kind == other.kind &&
          timestamp == other.timestamp &&
          timestampBasis == other.timestampBasis &&
          duration == other.duration &&
          kcal == other.kcal &&
          provenance == other.provenance &&
          label == other.label;

  @override
  int get hashCode => Object.hash(
    recordId,
    civilDay,
    kind,
    timestamp,
    timestampBasis,
    duration,
    kcal,
    provenance,
    label,
  );

  @override
  String toString() =>
      'PathEvent(recordId: $recordId, day: $civilDay, kind: ${kind.name}, '
      't: ${timeOfDayFraction.toStringAsFixed(3)}, basis: ${basisLabel.toLowerCase()}, '
      'kcal: $kcal, dur: $duration, prov: ${provenance.name})';
}

/// Extension on [PathPolicy] allowing domain callers to compute radii and areas
/// using kcal.
extension PathPolicyKcalExt on PathPolicy {
  double radiusForKcal(double? kcal) => radiusForEnergy(kcal);
  double areaForKcal(double? kcal) => areaForEnergy(kcal);
}

/// Pure resolver from CONFIRMED stored records to celestial path events on [day].
///
/// Honesty rules enforced:
/// 1. Pending records (`confirmed == false`) are strictly omitted.
/// 2. Intake kcal must be positive and finite (`kcal > 0 && kcal.isFinite`).
///    Null, zero, negative, NaN, and infinite intakes yield NO marks.
/// 3. Intake marks stay log-anchored labeled with duration `null`.
/// 4. Unknown duration NEVER gets invented length: an activity without duration
///    retains `duration == null`.
/// 5. Daily Health Connect totals (e.g. daily steps, daily calories burned)
///    have no timestamp and CANNOT yield timed events.
List<PathEvent> resolvePathEvents({
  required String day,
  required List<JournalEntry> journal,
  List<NutritionEntry> nutrition = const [],
  List<ActivityEntry> activities = const [],
  List<SleepEntry> sleeps = const [],
}) {
  final entries = <String, JournalEntry>{
    for (final entry in journal)
      if (entry.day == day) entry.id: entry,
  };

  final events = <PathEvent>[];

  // 1. Confirmed Nutrition (Intake)
  for (final meal in nutrition) {
    if (!meal.confirmed) continue;
    if (meal.day != day) continue;
    final parent = entries[meal.journalEntryId];
    if (parent == null) continue;
    if (!meal.kcal.isFinite || meal.kcal <= 0) continue;

    events.add(
      PathEvent(
        recordId: meal.id,
        civilDay: day,
        kind: PathEventKind.intake,
        timestamp: parent.at,
        timestampBasis: PathTimestampBasis.logAnchored,
        duration: null, // Unknown duration is never invented.
        kcal: meal.kcal,
        provenance: PathEventProvenance.fromSource(meal.source),
        label: meal.label,
      ),
    );
  }

  // 2. Confirmed Activities (Burn)
  for (final act in activities) {
    if (!act.confirmed) continue;
    if (act.day != day) continue;
    final parent = entries[act.journalEntryId];
    if (parent == null) continue;

    final double? kcal = act.kcal.isFinite && act.kcal > 0 ? act.kcal : null;
    final Duration? duration =
        act.minutes != null && act.minutes!.isFinite && act.minutes! > 0
            ? Duration(milliseconds: (act.minutes! * 60000).round())
            : null; // Never invent duration if unknown.

    events.add(
      PathEvent(
        recordId: act.id,
        civilDay: day,
        kind: PathEventKind.burn,
        timestamp: parent.at,
        timestampBasis: PathTimestampBasis.logAnchored,
        duration: duration,
        kcal: kcal,
        provenance: PathEventProvenance.fromSource(act.source),
        label: act.label,
      ),
    );
  }

  // 3. Completed Sleep sessions
  for (final sleep in sleeps) {
    if (sleep.day != day) continue;
    if (!sleep.isComplete) continue;

    final date = dayKeyDate(day);
    final startMillis = (sleep.startHours * 3600000).round();
    final startInstant = date.add(Duration(milliseconds: startMillis));
    final duration = Duration(
      milliseconds: (sleep.durationHours * 3600000).round(),
    );

    events.add(
      PathEvent(
        recordId: sleep.id,
        civilDay: day,
        kind: PathEventKind.sleep,
        timestamp: startInstant,
        timestampBasis: sleep.journalEntryId.isNotEmpty
            ? PathTimestampBasis.logAnchored
            : PathTimestampBasis.observed,
        duration: duration,
        kcal: null,
        provenance: PathEventProvenance.journal,
        label: 'Sleep',
      ),
    );
  }

  events.sort((a, b) {
    final t = a.timestamp.compareTo(b.timestamp);
    if (t != 0) return t;
    return a.kind.index.compareTo(b.kind.index);
  });

  return events;
}

/// Convenience resolver reading confirmed records from an [AppStore].
List<PathEvent> resolvePathEventsFromStore(AppStore store, String day) {
  return resolvePathEvents(
    day: day,
    journal: store.journal,
    nutrition: store.nutrition,
    activities: store.activities,
    sleeps: store.sleeps,
  );
}

/// Invariant enforcement: Daily Health Connect totals (e.g. cumulative daily
/// steps, calories burned, active minutes) are daily aggregates without any
/// timestamp or interval on the celestial path.
///
/// In accordance with the honesty invariant, they CANNOT yield timed path events.
List<PathEvent> resolveDailyHcTotalsToPathEvents(
  WearableDailyData? data,
  String day,
) {
  // Deliberately returns empty list: daily HC totals cannot yield timed events.
  return const [];
}
