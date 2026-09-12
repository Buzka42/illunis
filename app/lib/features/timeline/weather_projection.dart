import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/records.dart';
import '../../core/journal/marks.dart';
import '../../core/state/app_providers.dart';
import '../../core/state/civil_day.dart';
import '../../core/state/sky_state_source.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/weather/weather_model.dart';

class _WeatherRevision extends Notifier<int> {
  @override
  int build() {
    final service = ref.watch(weatherServiceProvider);
    void changed() => state++;
    service.addListener(changed);
    ref.onDispose(() => service.removeListener(changed));
    return 0;
  }
}

final _weatherRevisionProvider = NotifierProvider<_WeatherRevision, int>(
  _WeatherRevision.new,
);

final weatherViewProvider = Provider<WeatherObservation?>((ref) {
  ref.watch(_weatherRevisionProvider);
  ref.watch(storeRevisionProvider);
  ref.watch(
    skyStateProvider.select((s) => (s.epochDays, (s.timeOfDay * 1440).floor())),
  );
  if (ref.watch(storeProvider).profile.weatherSource == 'off') return null;
  final service = ref.watch(weatherServiceProvider);
  final profile = ref.watch(storeProvider).profile;
  if (!service.matchesLocation(profile.latitudeDeg, profile.longitudeDeg)) {
    return null;
  }
  final observation = service.cachedObservation;
  return observation == null ||
          observation.isStale(ref.watch(civilClockProvider)())
      ? null
      : observation;
});

enum PrecipitationKind { rain, snow, hail }

class PrecipitationMark {
  const PrecipitationMark(this.time, this.kind, this.weight);
  final double time, weight;
  final PrecipitationKind kind;
}

List<PrecipitationMark> precipitationMarks(
  WeatherObservation? observation,
  DateTime day,
) {
  if (observation == null) return const [];
  return [
    for (final point in observation.hourly24h)
      if (dayKey(point.time.toLocal()) == dayKey(day) &&
          point.precipitationMm != null &&
          point.precipitationMm!.isFinite &&
          point.precipitationMm! > 0 &&
          point.precipitationChance != null &&
          point.precipitationChance!.isFinite &&
          point.precipitationChance! > 0 &&
          precipitationKind(point.weatherCode) != null)
        PrecipitationMark(
          timeOfDayFraction(point.time.toLocal()),
          precipitationKind(point.weatherCode)!,
          (point.precipitationMm! / 4).clamp(0.0, 1.0) *
              point.precipitationChance!.clamp(0.0, 1.0),
        ),
  ];
}

// Open-Meteo WMO interpretation codes, documented in docs/WEATHER_V2.md.
PrecipitationKind? precipitationKind(int? code) => switch (code) {
  96 || 99 => PrecipitationKind.hail,
  71 || 73 || 75 || 77 || 85 || 86 => PrecipitationKind.snow,
  51 ||
  53 ||
  55 ||
  56 ||
  57 ||
  61 ||
  63 ||
  65 ||
  66 ||
  67 ||
  80 ||
  81 ||
  82 ||
  95 => PrecipitationKind.rain,
  _ => null,
};

class WeatherGlyphs extends ConsumerWidget {
  const WeatherGlyphs({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = precipitationMarks(
      ref.watch(weatherViewProvider),
      ref.watch(civilDayProvider),
    );
    final scrub = ref.watch(skyOverridesProvider).timeOfDay;
    final head = scrub ?? ref.watch(skyStateProvider).timeOfDay;
    return IgnorePointer(
      child: CustomPaint(
        painter: WeatherGlyphPainter(
          marks,
          head: head,
          scrub: scrub != null,
          textScale: MediaQuery.textScalerOf(context).scale(10) / 10,
        ),
      ),
    );
  }
}

class WeatherGlyphPainter extends CustomPainter {
  const WeatherGlyphPainter(
    this.marks, {
    this.head,
    this.scrub = false,
    this.textScale = 1,
  });
  final List<PrecipitationMark> marks;
  final double? head;
  final bool scrub;
  final double textScale;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < Space.margin * 2) return;
    for (final mark in marks) {
      final x = Space.margin + mark.time * (size.width - Space.margin * 2);
      // Forecast symbols yield to the clock label and debug LIVE control.
      if (head != null) {
        final headX = Space.margin + head! * (size.width - Space.margin * 2);
        if ((x - headX).abs() < 27 * textScale) continue;
        if (scrub &&
            (head! < 0.72
                ? x > size.width - Space.margin - 65 * textScale
                : x < Space.margin + 65 * textScale)) {
          continue;
        }
      }
      const y = 6.0;
      final radius = 1.0 + 2.0 * mark.weight;
      final ink = Paint()
        ..color = Inks.cool.withValues(alpha: 0.15 + 0.55 * mark.weight)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      switch (mark.kind) {
        case PrecipitationKind.rain:
          canvas.drawLine(
            Offset(x + radius / 2, y - radius),
            Offset(x - radius / 2, y + radius),
            ink,
          );
        case PrecipitationKind.snow:
          for (var axis = 0; axis < 3; axis++) {
            final angle = axis * math.pi / 3;
            final delta = Offset(math.cos(angle), math.sin(angle)) * radius;
            canvas.drawLine(Offset(x, y) - delta, Offset(x, y) + delta, ink);
          }
        case PrecipitationKind.hail:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, y),
              width: radius * 1.5,
              height: radius * 1.5,
            ),
            ink,
          );
      }
    }
  }

  @override
  bool shouldRepaint(WeatherGlyphPainter oldDelegate) =>
      oldDelegate.marks != marks ||
      oldDelegate.head != head ||
      oldDelegate.scrub != scrub ||
      oldDelegate.textScale != textScale;
}
