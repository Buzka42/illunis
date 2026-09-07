import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sky/celestial_math.dart';
import '../../core/sky/celestial_scene.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/state/sleep_record.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The day as a track: hour scale, the daylight span, last night's sleep
/// with its stages, and a playhead. Dragging scrubs `timeOfDay` through the
/// same override the debug sheet uses, so the whole sky follows the finger.
class TimelineBar extends ConsumerStatefulWidget {
  const TimelineBar({super.key, required this.scene});

  final ValueListenable<ResolvedScene?> scene;

  static const double height = 48;

  @override
  ConsumerState<TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends ConsumerState<TimelineBar> {
  static const _pad = Space.margin;

  void _scrubTo(double localX, double width) {
    final span = width - 2 * _pad;
    if (span <= 0) return;
    final t = ((localX - _pad) / span).clamp(0.0, 1.0);
    final n = ref.read(skyOverridesProvider.notifier);
    n.set(ref.read(skyOverridesProvider).copyWith(timeOfDay: t));
  }

  void _live() {
    final n = ref.read(skyOverridesProvider.notifier);
    n.set(ref.read(skyOverridesProvider).copyWith(timeOfDay: null));
  }

  @override
  Widget build(BuildContext context) {
    final scrub = ref.watch(skyOverridesProvider.select((o) => o.timeOfDay));
    final sleep = ref.watch(sleepRecordProvider);
    final marks = ref.watch(timelineMarksProvider);
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return SizedBox(
      height: TimelineBar.height,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _scrubTo(d.localPosition.dx, c.maxWidth),
              onHorizontalDragStart: (d) =>
                  _scrubTo(d.localPosition.dx, c.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _scrubTo(d.localPosition.dx, c.maxWidth),
              child: ValueListenableBuilder<ResolvedScene?>(
                valueListenable: widget.scene,
                builder: (context, scene, _) => CustomPaint(
                  painter: _TimelinePainter(
                    scene: scene,
                    sleep: sleep,
                    marks: marks,
                    scrub: scrub,
                    textScale: textScale,
                  ),
                ),
              ),
            ),
            // LIVE sits at whichever end the playhead's label is not.
            if (scrub != null)
              Positioned(
                right: scrub < 0.72 ? _pad - 6 : null,
                left: scrub < 0.72 ? null : _pad - 6,
                top: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _live,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Inks.warm,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: Type.label.copyWith(color: Inks.strong),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.scene,
    required this.sleep,
    required this.marks,
    required this.scrub,
    required this.textScale,
  });

  final ResolvedScene? scene;
  final SleepRecord? sleep;
  final List<double> marks;
  final double? scrub;
  final double textScale;

  static const _pad = Space.margin;
  static const _trackY = 31.0;
  static const _ink = Inks.full;
  static final Map<String, TextPainter> _cache = {};

  double _x(double t, Size size) => _pad + t * (size.width - 2 * _pad);

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene;
    if (s == null) return;
    // First layout can be width 0; Dart clamp throws if the floor is above
    // the ceiling, which is what x0+14 / x1-14 becomes on a thin bar.
    if (size.width < 2 * _pad + 32) return;
    final x0 = _x(0, size), x1 = _x(1, size);

    // Track.
    canvas.drawLine(
      Offset(x0, _trackY),
      Offset(x1, _trackY),
      Paint()
        ..color = _ink.withValues(alpha: 0.16)
        ..strokeWidth = 1,
    );
    _paintDaylight(canvas, size, s);
    _paintMarks(canvas, size);

    // Hour scale below the track.
    final tick = Paint()
      ..color = _ink.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      final x = _x(h / 24, size);
      final major = h % 6 == 0;
      canvas.drawLine(
        Offset(x, _trackY + 1.5),
        Offset(x, _trackY + (major ? 5.5 : 3.0)),
        tick,
      );
      if (major) {
        _text(
          canvas,
          h.toString().padLeft(2, '0'),
          Offset(x, _trackY + 8),
          size: 7.5,
          alpha: 0.38,
          anchor: h == 0
              ? Alignment.topLeft
              : (h == 24 ? Alignment.topRight : Alignment.topCenter),
        );
      }
    }

    // Playheads: the clock always, faint under a scrub; the scrub on top.
    final live = s.state.timeOfDay;
    final liveT = scrub == null ? live : null;
    final headT = liveT ?? scrub!;
    final lo = x0 + 14;
    final hi = x1 - 14;
    final headX = lo <= hi ? _x(headT, size).clamp(lo, hi) : (x0 + x1) * 0.5;

    if (sleep != null) _paintSleep(canvas, size, sleep!, headX);

    if (scrub != null) {
      // Where the clock actually is, kept as a reference.
      final x = _x(_liveTimeOfDay(), size);
      canvas.drawLine(
        Offset(x, _trackY - 9),
        Offset(x, _trackY + 5),
        Paint()
          ..color = _ink.withValues(alpha: 0.28)
          ..strokeWidth = 1,
      );
    }
    final t = headT;
    final x = _x(t, size);
    final head = Paint()
      ..color = (scrub != null ? Inks.warm : _ink).withValues(alpha: 0.85)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, _trackY - 15), Offset(x, _trackY + 6), head);
    canvas.drawCircle(
      Offset(x, _trackY),
      1.8,
      head..style = PaintingStyle.fill,
    );
    _text(
      canvas,
      formatHours(t),
      Offset(headX, _trackY - 18),
      size: 8.5,
      alpha: scrub != null ? 0.95 : 0.6,
      weight: 600,
      color: scrub != null ? Inks.warm : _ink,
      anchor: Alignment.bottomCenter,
    );
  }

  void _paintMarks(Canvas canvas, Size size) {
    if (marks.isEmpty) return;
    final tick = Paint()
      ..color = _ink.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final t in marks) {
      final x = _x(t.clamp(0.0, 1.0), size);
      canvas.drawLine(Offset(x, _trackY - 10), Offset(x, _trackY - 1), tick);
    }
  }

  /// The source's time, not the eased display time, so the reference mark
  /// does not slide when the scrub moves the display.
  double _liveTimeOfDay() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return now.difference(midnight).inMilliseconds / 86400000.0;
  }

  void _paintDaylight(Canvas canvas, Size size, ResolvedScene s) {
    final rise = s.sunrise, set = s.sunset;
    final x0 = _x(0, size), x1 = _x(1, size);
    final paint = Paint()..strokeWidth = 1.5;
    if (rise == null || set == null) {
      // Polar: either all day or none.
      if (s.sunDir.y > 0) {
        canvas.drawLine(
          Offset(x0, _trackY),
          Offset(x1, _trackY),
          paint..color = _ink.withValues(alpha: 0.5),
        );
      }
      return;
    }
    // Twilight softens both ends; ~35 minutes each side of the horizon.
    const tw = 0.024;
    final stops = <double>[
      (rise - tw).clamp(0.0, 1.0),
      (rise + tw).clamp(0.0, 1.0),
      (set - tw).clamp(0.0, 1.0),
      (set + tw).clamp(0.0, 1.0),
    ];
    if (rise < set) {
      paint.shader = ui.Gradient.linear(Offset(x0, 0), Offset(x1, 0), [
        _ink.withValues(alpha: 0),
        _ink.withValues(alpha: 0.55),
        _ink.withValues(alpha: 0.55),
        _ink.withValues(alpha: 0),
      ], stops);
      canvas.drawLine(
        Offset(_x(stops[0], size), _trackY),
        Offset(_x(stops[3], size), _trackY),
        paint,
      );
    } else {
      // Sun up across midnight: two spans.
      paint.color = _ink.withValues(alpha: 0.55);
      canvas.drawLine(
        Offset(x0, _trackY),
        Offset(_x(set, size), _trackY),
        paint,
      );
      canvas.drawLine(
        Offset(_x(rise, size), _trackY),
        Offset(x1, _trackY),
        paint,
      );
    }
  }

  void _paintSleep(Canvas canvas, Size size, SleepRecord r, double headX) {
    const base = _trackY - 4;
    // Fold hours onto the track; a span crossing midnight becomes two.
    void span(double h0, double h1, void Function(double x0, double x1) draw) {
      var a = h0, b = h1;
      if (b <= a) return;
      if (a < 0 && b > 0) {
        span(a, 0, draw);
        span(0, b, draw);
        return;
      }
      final t0 = ((a % 24) + 24) % 24 / 24, t1 = ((b % 24) + 24) % 24 / 24;
      final e = t1 == 0 ? 1.0 : t1;
      draw(_x(t0, size), _x(e, size));
    }

    if (r.segments.isEmpty) {
      span(r.startHours, r.endHours, (x0, x1) {
        canvas.drawRect(
          Rect.fromLTRB(x0, base - 8, x1, base),
          Paint()..color = _ink.withValues(alpha: 0.28),
        );
      });
    } else {
      for (final seg in r.segments) {
        final (h, a, c) = switch (seg.stage) {
          SleepStage.deep => (12.0, 0.55, _ink),
          SleepStage.light => (7.0, 0.30, _ink),
          SleepStage.rem => (9.0, 0.42, Inks.cool),
          SleepStage.awake => (2.0, 0.22, Inks.warm),
        };
        span(seg.startHours, seg.endHours, (x0, x1) {
          canvas.drawRect(
            Rect.fromLTRB(x0, base - h, x1 - 0.5, base),
            Paint()..color = c.withValues(alpha: a),
          );
        });
      }
    }

    // Label at the waking end, where the eye lands in the morning. It yields
    // to the playhead's time when the two would share the space.
    final labelT = (((r.endHours % 24) + 24) % 24) / 24;
    final lx = _x(labelT, size) + 6;
    final label = 'SLEEP ${formatDuration(r.asleepHours / 24)}';
    final w = _measure(label, size: 7.5, weight: 600).width;
    final clear = (headX + 24 < lx) || (headX - 24 > lx + w);
    if (!clear) return;
    _text(
      canvas,
      label,
      Offset(lx, base - 12),
      size: 7.5,
      alpha: 0.55,
      weight: 600,
      anchor: Alignment.centerLeft,
    );
  }

  Size _measure(String s, {required double size, int weight = 400}) {
    final key = 'm|$s|$size|$weight|$textScale';
    final tp = _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: Type.mono,
            fontSize: size * textScale,
            fontVariations: [ui.FontVariation('wght', weight.toDouble())],
            letterSpacing: 0.4,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    return tp.size;
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    required double size,
    required double alpha,
    required Alignment anchor,
    int weight = 400,
    Color color = _ink,
  }) {
    final key =
        '$s|$size|$weight|${(alpha * 100).round()}|$textScale|${color.toARGB32()}';
    final tp = _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: Type.mono,
            fontSize: size * textScale,
            fontVariations: [ui.FontVariation('wght', weight.toDouble())],
            color: color.withValues(alpha: alpha),
            letterSpacing: 0.4,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    final origin = Offset(
      at.dx - (anchor.x + 1) / 2 * tp.width,
      at.dy - (anchor.y + 1) / 2 * tp.height,
    );
    tp.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.scene != scene ||
      old.sleep != sleep ||
      old.scrub != scrub ||
      old.textScale != textScale ||
      !listEquals(old.marks, marks);
}
