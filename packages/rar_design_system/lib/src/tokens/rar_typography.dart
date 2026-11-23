import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/painting.dart';

import 'rar_colors.dart';

/// Typography scale built on the bundled Poppins family.
///
/// Styles carry no colour by default so they inherit from the theme;
/// use `.copyWith(color: ...)` or the theme's text theme where needed.
abstract final class RarTypography {
  /// Font family name, qualified with this package so apps resolve the
  /// bundled files.
  static const String fontFamily = 'Poppins';
  static const String fontPackage = 'rar_design_system';

  /// Fully-qualified family for `ThemeData.fontFamily`.
  static const String qualifiedFamily = 'packages/$fontPackage/$fontFamily';

  static const TextStyle _base = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Display — hero headlines ("Your Ride. Your Destination. Your Choice.")
  static final TextStyle display = _base.copyWith(
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static final TextStyle headlineLarge = _base.copyWith(
    fontSize: 28,
    height: 1.18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static final TextStyle headline = _base.copyWith(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static final TextStyle title = _base.copyWith(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle titleSmall = _base.copyWith(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle body = _base.copyWith(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle bodySmall = _base.copyWith(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle label = _base.copyWith(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static final TextStyle caption = _base.copyWith(
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Builds a Material [TextTheme] in the given base colour.
  static TextTheme textTheme({required Color color, required Color muted}) {
    return TextTheme(
      displayLarge: display.copyWith(color: color),
      displayMedium: headlineLarge.copyWith(color: color),
      headlineLarge: headlineLarge.copyWith(color: color),
      headlineMedium: headline.copyWith(color: color),
      headlineSmall: headline.copyWith(color: color, fontSize: 20),
      titleLarge: title.copyWith(color: color),
      titleMedium: titleSmall.copyWith(color: color),
      titleSmall: titleSmall.copyWith(color: color, fontSize: 14),
      bodyLarge: body.copyWith(color: color, fontSize: 16),
      bodyMedium: body.copyWith(color: color),
      bodySmall: bodySmall.copyWith(color: muted),
      labelLarge: label.copyWith(color: color),
      labelMedium: caption.copyWith(color: color, fontSize: 12),
      labelSmall: caption.copyWith(color: muted),
    );
  }

  /// Default text colours.
  static const Color onLight = RarColors.textPrimary;
  static const Color onDark = RarColors.textOnDark;
}
