import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';

/// Normalised, simultaneous atmospheric components. A producer translates
/// its observations into these amounts; the renderer knows no condition codes.
/// [SkyState.weather] being null means unobserved/clear-looking, whereas
/// [SkyWeather.clear] is an explicitly known clear observation.
@immutable
class SkyWeather {
  const SkyWeather({
    required this.cloudCoverage,
    this.cumulus = 0.5,
    this.cirrus = 0,
    this.rain = 0,
    this.fog = 0,
    this.snow = 0,
  }) : assert(cloudCoverage >= 0 && cloudCoverage <= 1),
       assert(cumulus >= 0 && cumulus <= 1),
       assert(cirrus >= 0 && cirrus <= 1),
       assert(rain >= 0 && rain <= 1),
       assert(fog >= 0 && fog <= 1),
       assert(snow >= 0 && snow <= 1);

  const SkyWeather.clear()
    : cloudCoverage = 0,
      cumulus = 0.5,
      cirrus = 0,
      rain = 0,
      fog = 0,
      snow = 0;

  /// Fraction of the sky covered; one is an optically closed overcast.
  final double cloudCoverage;

  /// Cloud character: zero is a stratus sheet, one is rounded cumulus.
  final double cumulus;

  /// Blend toward thin, high-altitude ice-cloud filaments.
  final double cirrus;
  final double rain;
  final double fog;
  final double snow;

  bool get isClear => cloudCoverage == 0 && rain == 0 && fog == 0 && snow == 0;

  SkyWeather copyWith({
    double? cloudCoverage,
    double? cumulus,
    double? cirrus,
    double? rain,
    double? fog,
    double? snow,
  }) => SkyWeather(
    cloudCoverage: cloudCoverage ?? this.cloudCoverage,
    cumulus: cumulus ?? this.cumulus,
    cirrus: cirrus ?? this.cirrus,
    rain: rain ?? this.rain,
    fog: fog ?? this.fog,
    snow: snow ?? this.snow,
  );

  /// The view may fade an absent observation in/out through a clear-looking
  /// envelope. This does not replace null in the source with an observation.
  static SkyWeather? lerp(SkyWeather? a, SkyWeather? b, double t) {
    if (t <= 0 || a == b) return a;
    if (t >= 1) return b;
    final from = a ?? const SkyWeather.clear();
    final to = b ?? const SkyWeather.clear();
    final result = SkyWeather(
      cloudCoverage: lerpDouble(from.cloudCoverage, to.cloudCoverage, t)!,
      cumulus: lerpDouble(from.cumulus, to.cumulus, t)!,
      cirrus: lerpDouble(from.cirrus, to.cirrus, t)!,
      rain: lerpDouble(from.rain, to.rain, t)!,
      fog: lerpDouble(from.fog, to.fog, t)!,
      snow: lerpDouble(from.snow, to.snow, t)!,
    );
    if (b == null &&
        result.cloudCoverage + result.rain + result.fog + result.snow < 0.001) {
      return null;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is SkyWeather &&
      cloudCoverage == other.cloudCoverage &&
      cumulus == other.cumulus &&
      cirrus == other.cirrus &&
      rain == other.rain &&
      fog == other.fog &&
      snow == other.snow;

  @override
  int get hashCode =>
      Object.hash(cloudCoverage, cumulus, cirrus, rain, fog, snow);

  @override
  String toString() =>
      'Weather(cloud=$cloudCoverage cumulus=$cumulus cirrus=$cirrus '
      'rain=$rain fog=$fog snow=$snow)';
}
