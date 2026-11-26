import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_spacing.dart';
import '../tokens/rar_typography.dart';

/// Material themes for Rent A Ride.
///
/// * [light] — in-app screens (home, booking, wallet): white / light-blue
///   background with navy text and royal actions.
/// * [dark] — immersive screens (welcome, trip in progress): deep navy with
///   translucent glass panels.
abstract final class RarTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: RarColors.royal,
      onPrimary: RarColors.white,
      primaryContainer: isDark ? RarColors.navy700 : RarColors.surfaceLight,
      onPrimaryContainer: isDark ? RarColors.white : RarColors.navy,
      secondary: RarColors.cyan,
      onSecondary: RarColors.navy,
      tertiary: RarColors.navy,
      onTertiary: RarColors.white,
      error: RarColors.danger,
      onError: RarColors.white,
      surface: isDark ? RarColors.navy : RarColors.white,
      onSurface: isDark ? RarColors.white : RarColors.navy,
      onSurfaceVariant: isDark
          ? RarColors.textOnDarkSecondary
          : RarColors.textSecondary,
      surfaceContainerHighest: isDark
          ? RarColors.navy700
          : RarColors.surfaceLight,
      outline: isDark ? RarColors.glassBorderDark : RarColors.outlineLight,
      outlineVariant: isDark
          ? RarColors.glassFillDarkStrong
          : RarColors.outlineLight,
      shadow: RarColors.navy950,
      scrim: RarColors.navy950,
      inverseSurface: isDark ? RarColors.white : RarColors.navy,
      onInverseSurface: isDark ? RarColors.navy : RarColors.white,
      inversePrimary: RarColors.cyan,
    );

    final textTheme = RarTypography.textTheme(
      color: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: RarRadius.button);
    const buttonSize = Size.fromHeight(RarSpacing.buttonHeight);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: RarTypography.qualifiedFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? RarColors.navy : RarColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        titleTextStyle: RarTypography.title.copyWith(color: scheme.onSurface),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          backgroundColor: RarColors.royal,
          foregroundColor: RarColors.white,
          textStyle: RarTypography.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: RarTypography.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? RarColors.cyan : RarColors.royal,
          textStyle: RarTypography.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? RarColors.glassFillDark : RarColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RarSpacing.lg,
          vertical: RarSpacing.lg,
        ),
        hintStyle: RarTypography.body.copyWith(
          color: isDark ? RarColors.textOnDarkMuted : RarColors.textMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: RarRadius.card,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RarRadius.card,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: RarRadius.card,
          borderSide: BorderSide(color: RarColors.royal, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: RarRadius.card,
          borderSide: BorderSide(color: RarColors.danger),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? RarColors.navy900 : RarColors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: RarRadius.sheet),
        showDragHandle: true,
        dragHandleColor: isDark
            ? RarColors.textOnDarkMuted
            : RarColors.outlineLight,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RarColors.navy,
        contentTextStyle: RarTypography.body.copyWith(color: RarColors.white),
        shape: const RoundedRectangleBorder(borderRadius: RarRadius.card),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RarColors.royal,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
