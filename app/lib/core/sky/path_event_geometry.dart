import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'celestial_math.dart';
import 'celestial_scene.dart';
import 'sky_camera.dart';

/// Which celestial body's diurnal path events anchor to.
enum CelestialTrack {
  /// The sun's diurnal path across the sky.
  solar,

  /// The moon's path across the sky.
  lunar,

  /// Solar by day / twilight; lunar at night when lit; falls back to solar when moonless.
  autoActive,
}

/// A pure geometric event presented to the sky rendering layer.
///
/// The sky layer owns what figures look like, not what they mean.
/// Grounded health records are converted into [SkyPathEvent]s before reaching geometry.
@immutable
class SkyPathEvent {
  const SkyPathEvent({
    required this.id,
    required this.timeOfDay,
    this.durationFraction,
    this.energy,
    this.isIntake = true,
    this.isLogAnchored = true,
    this.label,
  });

  /// Unique record identifier.
  final String id;

  /// Day fraction, 0.0 .. 1.0.
  final double timeOfDay;

  /// Known duration as fraction of a 24h day (e.g. 45 min / 1440 min).
  /// Strictly null when duration is unknown. Length is NEVER invented.
  final double? durationFraction;

  /// Measured energy/magnitude (e.g. intake or burn), positive and finite, or null.
  final double? energy;

  /// True for intake, false for burn/activity.
  final bool isIntake;

  /// True if timestamp reflects journal entry logging instant.
  final bool isLogAnchored;

  /// Descriptive display label.
  final String? label;

  String get basisLabel => isLogAnchored ? 'Log-anchored' : 'Observed';
}

/// Policy governing how path events are projected and sized.
@immutable
class PathPolicy {
  const PathPolicy({
    this.track = CelestialTrack.autoActive,
    this.baseRadius = 2.5,
    this.minRadius = 1.5,
    this.maxRadius = 14.0,
    this.referenceEnergy = 500.0,
    this.sampleStepMinutes = 3.0,
    this.coincidentSpacingDp = 6.0,
    this.coincidentTimeThresholdMinutes = 2.0,
    this.fallbackToSolarWhenMoonless = true,
  });

  final CelestialTrack track;
  final double baseRadius;
  final double minRadius;
  final double maxRadius;
  final double referenceEnergy;
  final double sampleStepMinutes;
  final double coincidentSpacingDp;
  final double coincidentTimeThresholdMinutes;
  final bool fallbackToSolarWhenMoonless;

  /// Area-proportional radius mapping:
  /// Visual circle area A = pi * r^2 is directly proportional to energy magnitude.
  /// Doubling energy doubles the area (radius scales by sqrt(2)).
  /// Quadrupling energy quadruples area (radius scales by 2).
  double radiusForEnergy(double? energyValue) {
    if (energyValue == null || energyValue <= 0 || !energyValue.isFinite) {
      return baseRadius;
    }
    final raw = baseRadius * math.sqrt(energyValue / referenceEnergy);
    return raw.clamp(minRadius, maxRadius);
  }

  /// Visual area in square pixels for a given energy magnitude.
  double areaForEnergy(double? energyValue) {
    final r = radiusForEnergy(energyValue);
    return math.pi * r * r;
  }

  /// Reuses sunDirectionAt / moonDirectionAt without independent arcs.
  Vec3 directionAt(ResolvedScene scene, double timeOfDay) {
    final t = timeOfDay.clamp(0.0, 1.0);
    switch (track) {
      case CelestialTrack.solar:
        return scene.sunDirectionAt(t);
      case CelestialTrack.lunar:
        return scene.moonDirectionAt(t);
      case CelestialTrack.autoActive:
        // Daytime or twilight uses the sun path.
        if (scene.sunAltitudeRad > -12 * degToRad) {
          return scene.sunDirectionAt(t);
        }
        // At night: use lunar if lit, else fallback to solar if moonless.
        if (isMoonlessScene(scene) && fallbackToSolarWhenMoonless) {
          return scene.sunDirectionAt(t);
        }
        return scene.moonDirectionAt(t);
    }
  }
}

/// Detects whether the scene is moonless (negligible illumination or new moon).
bool isMoonlessScene(ResolvedScene scene) {
  return scene.moonIllumination < 0.05 ||
      scene.state.moonPhase < 0.02 ||
      scene.state.moonPhase > 0.98;
}

/// A projected sample point along a continuous event streak.
@immutable
class ProjectedStreakSample {
  const ProjectedStreakSample({
    required this.timeOfDay,
    required this.direction,
    required this.screenPoint,
    required this.isVisible,
    required this.isAboveHorizon,
  });

  /// Day fraction, 0.0 .. 1.0 (or > 1.0 when wrapping across midnight).
  final double timeOfDay;

  /// 3D celestial direction on the horizontal unit sphere.
  final Vec3 direction;

  /// Projected 2D screen coordinate, or null if behind camera.
  final Offset? screenPoint;

  /// True if [screenPoint] is within the camera viewport bounds.
  final bool isVisible;

  /// True if above the horizon (direction.y >= 0).
  final bool isAboveHorizon;
}

/// Projected geometry for a single [SkyPathEvent].
@immutable
class ProjectedPathEvent {
  const ProjectedPathEvent({
    required this.event,
    required this.anchorDirection,
    required this.anchorScreenPoint,
    required this.isAnchorVisible,
    required this.isAboveHorizon,
    required this.radius,
    required this.area,
    required this.streakSamples,
    required this.isClipped,
    required this.isOffscreen,
    required this.isCoincident,
    this.coincidentIndex = 0,
    this.coincidentCount = 1,
    this.coincidentOffset = Offset.zero,
    required this.honestyLabel,
  });

  final SkyPathEvent event;

  /// 3D unit direction at the event's anchor timestamp.
  final Vec3 anchorDirection;

  /// Projected screen position of the anchor timestamp (null if behind camera).
  final Offset? anchorScreenPoint;

  /// True if the anchor point is within the camera's screen bounds.
  final bool isAnchorVisible;

  /// True if anchor point is in the sky above the horizon.
  final bool isAboveHorizon;

  /// Area-proportional mark radius.
  final double radius;

  /// Area of the mark in square pixels.
  final double area;

  /// Continuous samples along the path for events with known duration.
  /// Empty for events with unknown or zero duration.
  final List<ProjectedStreakSample> streakSamples;

  /// True if part of the streak is clipped by viewport or behind camera.
  final bool isClipped;

  /// True if anchor and all streak points are outside viewport / behind camera.
  final bool isOffscreen;

  /// True if another event shares the same anchor timestamp.
  final bool isCoincident;

  /// 0-indexed position within the coincident cluster.
  final int coincidentIndex;

  /// Total count of coincident events at this timestamp.
  final int coincidentCount;

  /// Perpendicular offset applied to prevent coincident occlusion.
  final Offset coincidentOffset;

  /// Transparent user-facing label disclosing timestamp basis.
  final String honestyLabel;

  /// Effective screen position including coincident displacement.
  Offset? get effectiveScreenPoint {
    if (anchorScreenPoint == null) return null;
    return anchorScreenPoint! + coincidentOffset;
  }
}

/// Precomputed geometry cache prepared completely OUTSIDE of paint.
///
/// Paint methods simply iterate over this cache without performing any
/// stereographic projections, trigonometry, or list allocations.
@immutable
class PathEventGeometryCache {
  const PathEventGeometryCache({
    required this.projectedEvents,
    required this.policy,
    required this.isMoonless,
    required this.cameraYawRad,
  });

  final List<ProjectedPathEvent> projectedEvents;
  final PathPolicy policy;
  final bool isMoonless;
  final double cameraYawRad;

  List<ProjectedPathEvent> get visibleEvents =>
      projectedEvents.where((e) => !e.isOffscreen).toList();
}

/// Pure geometry pipeline resolving events, ResolvedScene, and SkyCamera into
/// projected points and streak samples.
class PathEventGeometryPipeline {
  const PathEventGeometryPipeline._();

  /// Pure resolver computing projected geometry outside paint.
  ///
  /// Reuses [scene.sunDirectionAt] and [scene.moonDirectionAt] with [camera.project].
  /// No independent arcs are created.
  static PathEventGeometryCache compute({
    required List<SkyPathEvent> events,
    required ResolvedScene scene,
    required SkyCamera camera,
    PathPolicy policy = const PathPolicy(),
  }) {
    final isMoonless = isMoonlessScene(scene);

    if (events.isEmpty) {
      return PathEventGeometryCache(
        projectedEvents: const [],
        policy: policy,
        isMoonless: isMoonless,
        cameraYawRad: camera.azimuthRad,
      );
    }

    // 1. Group coincident events within coincident threshold
    final thresholdFraction = policy.coincidentTimeThresholdMinutes / (24 * 60);
    final clusters = <List<SkyPathEvent>>[];
    for (final ev in events) {
      if (clusters.isEmpty) {
        clusters.add([ev]);
      } else {
        final lastCluster = clusters.last;
        final diff = (ev.timeOfDay - lastCluster.first.timeOfDay).abs();
        if (diff <= thresholdFraction) {
          lastCluster.add(ev);
        } else {
          clusters.add([ev]);
        }
      }
    }

    final projected = <ProjectedPathEvent>[];

    for (final cluster in clusters) {
      final isClusterCoincident = cluster.length > 1;
      final count = cluster.length;

      for (var idx = 0; idx < count; idx++) {
        final ev = cluster[idx];
        final t0 = ev.timeOfDay;
        final anchorDir = policy.directionAt(scene, t0);
        final anchorPt = camera.project(anchorDir);
        final anchorVis = anchorPt != null && camera.contains(anchorPt);
        final isAbove = anchorDir.y >= 0;

        // Area-proportional mark size
        final radius = policy.radiusForEnergy(ev.energy);
        final area = policy.areaForEnergy(ev.energy);

        // Calculate perpendicular normal for coincident layout
        Offset coincidentOffset = Offset.zero;
        if (isClusterCoincident && anchorPt != null) {
          // Tangent sample along the celestial path
          final aheadDir = policy.directionAt(scene, (t0 + 1 / 1440) % 1.0);
          final aheadPt = camera.project(aheadDir);
          if (aheadPt != null) {
            final tangent = aheadPt - anchorPt;
            final dist = tangent.distance;
            if (dist > 0.001) {
              final normal = Offset(-tangent.dy, tangent.dx) / dist;
              final shiftFactor = idx - (count - 1) / 2.0;
              coincidentOffset = normal * (shiftFactor * policy.coincidentSpacingDp);
            }
          }
        }

        // Streak sampling: ONLY when duration is known!
        // Honesty invariant: unknown duration NEVER gets invented length.
        final streakSamples = <ProjectedStreakSample>[];
        var isClipped = false;

        if (ev.durationFraction != null && ev.durationFraction! > 0) {
          final durDays = ev.durationFraction!;
          final durMinutes = durDays * 1440.0;
          final stepCount = math.max(
            2,
            (durMinutes / policy.sampleStepMinutes).ceil(),
          );

          for (var s = 0; s <= stepCount; s++) {
            final sampleT = t0 + durDays * (s / stepCount);
            // Midnight handling: wrap around civil day
            final sampleTNormalized = sampleT % 1.0;
            final sampleDir = policy.directionAt(scene, sampleTNormalized);
            final samplePt = camera.project(sampleDir);
            final sampleVis = samplePt != null && camera.contains(samplePt);

            if (samplePt == null || !sampleVis) {
              isClipped = true;
            }

            streakSamples.add(
              ProjectedStreakSample(
                timeOfDay: sampleT,
                direction: sampleDir,
                screenPoint: samplePt,
                isVisible: sampleVis,
                isAboveHorizon: sampleDir.y >= 0,
              ),
            );
          }
        }

        // Check if entirely offscreen
        final bool isOffscreen;
        if (streakSamples.isEmpty) {
          isOffscreen = !anchorVis;
        } else {
          final anyStreakVisible = streakSamples.any((s) => s.isVisible);
          isOffscreen = !anchorVis && !anyStreakVisible;
        }

        // Honesty label
        final totalMinutes = (t0 * 1440).round();
        final hours = (totalMinutes ~/ 60) % 24;
        final minutes = totalMinutes % 60;
        final hh = hours.toString().padLeft(2, '0');
        final mm = minutes.toString().padLeft(2, '0');
        final honestyLabel = ev.isLogAnchored
            ? 'LOGGED $hh:$mm [${ev.basisLabel}]'
            : '$hh:$mm [${ev.basisLabel}]';

        projected.add(
          ProjectedPathEvent(
            event: ev,
            anchorDirection: anchorDir,
            anchorScreenPoint: anchorPt,
            isAnchorVisible: anchorVis,
            isAboveHorizon: isAbove,
            radius: radius,
            area: area,
            streakSamples: streakSamples,
            isClipped: isClipped,
            isOffscreen: isOffscreen,
            isCoincident: isClusterCoincident,
            coincidentIndex: idx,
            coincidentCount: count,
            coincidentOffset: coincidentOffset,
            honestyLabel: honestyLabel,
          ),
        );
      }
    }

    return PathEventGeometryCache(
      projectedEvents: projected,
      policy: policy,
      isMoonless: isMoonless,
      cameraYawRad: camera.azimuthRad,
    );
  }
}
