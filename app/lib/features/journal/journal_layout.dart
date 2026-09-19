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
  static const double writingLineBand = 46.0;

  /// Standard row height for a single unconfirmed estimate row in the dock.
  static const double pendingRowBand = 40.0;

  /// Additional band height for the CONFIRM ALL action when pending count > 1.
  static const double pendingConfirmAllBand = 28.0;

  /// Maximum height the pending dock may occupy so it never squashes the ground pager.
  static const double maxPendingHeight = 148.0;

  /// Unscaled baseline height for one entry tile row.
  static const double baseEntryRowHeight = 52.0;

  /// Unscaled baseline height for the pagination navigation bar.
  static const double baseNavWordHeight = 22.0;

  /// True when virtual keyboard is considered active.
  bool get isKeyboardOpen => keyboardInset > 8.0;

  /// Scaled row height for an entry tile.
  double get entryRowHeight => baseEntryRowHeight * textScale;

  /// Scaled height for the pagination row.
  double get navWordHeight => baseNavWordHeight * textScale;

  /// Total effective dock height on the journal surface.
  double get effectiveDockHeight =>
      writingLineBand + (isKeyboardOpen ? 0.0 : pendingHeight);

  /// Available content height for journal entry lists.
  double get availableContentHeight =>
      math.max(0.0, groundHeight - effectiveDockHeight);

  /// Computes the number of entries that fit on one page without scrolling.
  int entriesPerPage(double availableHeight) {
    final count = ((availableHeight - navWordHeight) / entryRowHeight).floor();
    return count.clamp(1, 100);
  }

  /// Calculates clamped dock height for a given pending count.
  static double calculatePendingHeight(
    int pendingCount, {
    double maxHeight = maxPendingHeight,
  }) {
    if (pendingCount <= 0) return 0.0;
    final unbounded = pendingCount * pendingRowBand +
        (pendingCount > 1 ? pendingConfirmAllBand : 0.0);
    return unbounded > maxHeight ? maxHeight : unbounded;
  }
}
