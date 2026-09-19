import 'dart:math' as math;

/// Measurable inputs to journal layout geometry, separating geometry calculations
/// from widget rendering.
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

  /// Standard row height for a single unconfirmed estimate row in the dock.
  static const double pendingRowBand = 88.0;

  /// Additional band height for the CONFIRM ALL action when pending count > 1.
  static const double pendingConfirmAllBand = 44.0;

  /// Maximum height the pending dock may occupy so it never squashes the ground pager.
  static const double maxPendingHeight = 148.0;

  /// Unscaled baseline height for one entry tile row.
  static const double baseEntryRowHeight = 100.0;

  /// Unscaled baseline height for the pagination navigation bar.
  static const double baseNavWordHeight = 44.0;

  /// True when virtual keyboard is considered active.
  bool get isKeyboardOpen => keyboardInset > 8.0;

  /// Scaled row height for an entry tile.
  double get entryRowHeight => baseEntryRowHeight * textScale;

  /// Scaled height for the pagination row.
  double get navWordHeight => math.max(baseNavWordHeight, 11 * textScale);

  /// Total effective dock height on the journal surface.
  double get effectiveDockHeight =>
      writingHeight(textScale) + (isKeyboardOpen ? 0.0 : pendingHeight);

  /// Available content height for journal entry lists.
  double get availableContentHeight =>
      math.max(0.0, groundHeight - effectiveDockHeight);

  /// Estimates a quiet page of up to four entries; long prose can still scroll.
  int entriesPerPage(double availableHeight) {
    final count = ((availableHeight - navWordHeight) / entryRowHeight).floor();
    return count.clamp(1, 4);
  }

  /// Calculates clamped dock height for a given pending count.
  static double calculatePendingHeight(
    int pendingCount, {
    double maxHeight = maxPendingHeight,
  }) {
    if (pendingCount <= 0) return 0.0;
    final unbounded =
        pendingCount * pendingRowBand +
        (pendingCount > 1 ? pendingConfirmAllBand : 0.0);
    return unbounded > maxHeight ? maxHeight : unbounded;
  }
}
