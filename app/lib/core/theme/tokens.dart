export '../sky/sky_camera.dart' show kHorizonFraction;

/// Spacing and geometry. There are almost no radii on purpose.
class Space {
  const Space._();
  static const double margin = 22;
  static const double gutter = 14;
  static const double row = 12;
  static const double hairline = 1;
}

/// Ground-band layout under the horizon: the compass scale, then the
/// timeline, then the surfaces.
const double kCompassBandHeight = 22;
