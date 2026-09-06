import 'package:flutter/material.dart';

/// Every TextStyle in the app comes from here. Two families: Inter for
/// words, JetBrains Mono for anything that is a figure, a unit, a bearing,
/// a time — the instrument voice. Figures are tabular by construction.
class Inks {
  const Inks._();

  static const Color full = Color(0xFFEEF1F6);
  static Color get strong => full.withValues(alpha: 0.92);
  static Color get body => full.withValues(alpha: 0.78);
  static Color get muted => full.withValues(alpha: 0.52);
  static Color get faint => full.withValues(alpha: 0.30);
  static Color get hairline => full.withValues(alpha: 0.16);
  static const Color warm = Color(0xFFF2C99A);
  static const Color cool = Color(0xFFB9C6E0);
  static const Color negative = Color(0xFFE8A39A);
}

class Type {
  const Type._();

  static const String text = 'Inter';
  static const String mono = 'JetBrains Mono';

  static TextStyle _m(
    double size,
    int weight, {
    double? spacing,
    Color? color,
    double height = 1.1,
  }) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      fontVariations: [FontVariation('wght', weight.toDouble())],
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: spacing,
      color: color ?? Inks.strong,
      height: height,
    );
  }

  static TextStyle _t(
    double size,
    FontWeight weight, {
    double? spacing,
    Color? color,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: text,
      fontSize: size,
      fontWeight: weight,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: spacing,
      color: color ?? Inks.body,
      height: height,
    );
  }

  /// Eyebrows and column heads: `RECOVERY`, `SUNSET`.
  static TextStyle get label => _m(9.5, 500, spacing: 1.4, color: Inks.muted);

  /// Small instrument text: readouts, units, footers.
  static TextStyle get micro => _m(10, 400, spacing: 0.4, color: Inks.muted);

  /// A figure in a table row.
  static TextStyle get figure => _m(17, 400, spacing: -0.2, color: Inks.strong);

  /// The one big number on a surface.
  static TextStyle get figureLarge =>
      _m(40, 300, spacing: -1.2, color: Inks.strong, height: 1.0);

  /// Clock in the header.
  static TextStyle get clock => _m(12, 400, spacing: 0.6, color: Inks.body);

  /// Wordmark: text face, wide, small.
  static TextStyle get wordmark =>
      _t(11, FontWeight.w600, spacing: 3.2, color: Inks.strong, height: 1.0);

  static TextStyle get title =>
      _t(22, FontWeight.w400, spacing: -0.3, color: Inks.strong, height: 1.2);
  static TextStyle get body => _t(14.5, FontWeight.w400);
  static TextStyle get caption => _t(12, FontWeight.w400, color: Inks.muted);
  static TextStyle get control =>
      _t(12.5, FontWeight.w500, spacing: 0.3, color: Inks.strong, height: 1.0);

  static TextTheme get theme => TextTheme(
    displayLarge: figureLarge,
    displayMedium: figureLarge,
    displaySmall: figureLarge,
    headlineLarge: title,
    headlineMedium: title,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: body,
    titleSmall: control,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: control,
    labelMedium: label,
    labelSmall: micro,
  );
}
