import 'dart:math' as math;

/// Measurable inputs to journal layout geometry, separating geometry calculations
/// from widget rendering.
///
/// ONE ground composition: the journal surface is a single vertical budget —
/// record viewport (flexible) + pending dock (clamped) + writer (measured).
/// The shell reserves the ground rect; [JournalPage] spends it from these
/// inputs so the three regions hold disjoint rects across keyboard, editing,
/// error, pending and page transitions.
class JournalLayoutInputs {
  const JournalLayoutInputs({
    required this.groundHeight,
    required this.keyboardInset,
    required this.pendingHeight,
    required this.textScale,
  });

  /// Total ground height available for journal surfaces.
  final double groundHeight;

  /// Bottom inset from virtual keyboard / IME.
  final double keyboardInset;

  /// Height occupied by the pending estimates dock.
  final double pendingHeight;

  /// Text scale factor (e.g. from MediaQuery.textScalerOf(context).scale(10) / 10).
  final double textScale;

  /// Vertical space the writing line occupies above the surface switch.
  static const double writingLineBand = 93.0;

  static double fieldHeight(double scale) => math.max(48.0, 22 * scale + 20);

  static double writingHeight(
    double scale, {
    bool editing = false,
    bool error = false,
  }) =>
      1 +
      fieldHeight(scale) +
      44 +
      (editing ? 6 + 11 * scale : 0) +
      (error ? 8 + 28 * scale : 0);

  /// Height of one estimate row: stacked DROP + CONFIRM (two 44dp targets)
  /// in the fixed 116dp lane plus row padding. The flexible caption beside
  /// the lane is usually shorter; taller captions scroll inside the dock.
  static const double pendingRowBand = 96.0;

  /// Header band: the `ESTIMATES · n` line plus its padding.
  static const double pendingHeaderBand = 26.0;

  /// Additional band height for the CONFIRM ALL action when pending count > 1.
  static const double pendingConfirmAllBand = 44.0;

  /// Maximum height the pending dock may occupy so it never squashes the ground pager.
  static const double maxPendingHeight = 148.0;

  /// Minimum record viewport height kept free so the list never collapses
  /// under the dock + writer, even with editing/error bands and large text.
  static const double minRecordHeight = 48.0;

  /// Bottom chrome inside the journal page padding the ground Column.
  /// The shell lift accounts for it so the measured writer fits exactly.
  static const double pageBottomChrome = 4.0;

  /// True when virtual keyboard is considered active.
  bool get isKeyboardOpen => keyboardInset > 8.0;

  /// Total effective dock height on the journal surface.
  double get effectiveDockHeight =>
      writingHeight(textScale) + (isKeyboardOpen ? 0.0 : pendingHeight);

  /// Available content height for journal entry lists.
  double get availableContentHeight =>
      math.max(0.0, groundHeight - effectiveDockHeight);

  /// Clamps a wanted pending height into the single ground budget:
  /// ground − writer − minimum record viewport. The dock never overlaps the
  /// writer and never squeezes the record below [minRecordHeight].
  static double pendingClamp({
    required double groundHeight,
    required double writingHeight,
    required double want,
  }) =>
      math.min(
        want,
        math.max(0.0, groundHeight - writingHeight - minRecordHeight),
      );

  /// Calculates clamped dock height for a given pending count: header plus
  /// one row band per estimate plus CONFIRM ALL when there is more than one.
  /// The unbounded height matches real content so the first rows are never
  /// clipped; overflow scrolls inside the dock.
  static double calculatePendingHeight(
    int pendingCount, {
    double maxHeight = maxPendingHeight,
  }) {
    if (pendingCount <= 0) return 0.0;
    final unbounded =
        pendingHeaderBand +
        pendingCount * pendingRowBand +
        (pendingCount > 1 ? pendingConfirmAllBand : 0.0);
    return unbounded > maxHeight ? maxHeight : unbounded;
  }
}
