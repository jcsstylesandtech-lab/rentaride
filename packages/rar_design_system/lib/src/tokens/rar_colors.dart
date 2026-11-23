import 'package:flutter/painting.dart';

/// Rent A Ride colour palette.
///
/// Brand colours come straight from the reference design system:
/// navy `#061B49`, royal `#0866FF`, cyan `#00C8FF`, white `#FFFFFF`.
/// Everything else is derived from them so the identity stays consistent.
abstract final class RarColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  /// Primary — deep navy blue.
  static const Color navy = Color(0xFF061B49);

  /// Secondary — royal blue. Primary actions, active states.
  static const Color royal = Color(0xFF0866FF);

  /// Accent — electric cyan. Highlights, live indicators.
  static const Color cyan = Color(0xFF00C8FF);

  static const Color white = Color(0xFFFFFFFF);

  // ── Navy scale (dark surfaces) ─────────────────────────────────────────
  static const Color navy950 = Color(0xFF020C26);
  static const Color navy900 = Color(0xFF041237);
  static const Color navy800 = navy;
  static const Color navy700 = Color(0xFF0B2A6B);
  static const Color navy600 = Color(0xFF123A8F);

  // ── Light surfaces ─────────────────────────────────────────────────────
  /// App background on light screens (white → light blue).
  static const Color background = Color(0xFFF4F8FF);
  static const Color surfaceLight = Color(0xFFE8F0FF);
  static const Color outlineLight = Color(0xFFD5E2FA);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = navy;
  static const Color textSecondary = Color(0xFF51608A);
  static const Color textMuted = Color(0xFF8A97B8);
  static const Color textOnDark = white;
  static const Color textOnDarkSecondary = Color(0xCCFFFFFF); // 80 %
  static const Color textOnDarkMuted = Color(0x99FFFFFF); // 60 %

  // ── Glass ──────────────────────────────────────────────────────────────
  /// Fill for glass panels placed on dark/navy backgrounds.
  // Blue-tinted rather than plain white, so panels read as blue glass on
  // navy (plain white at low opacity turns grey).
  static const Color glassFillDark = Color(0x3D2D63C8); // blue 24 %
  static const Color glassFillDarkStrong = Color(0x573A74DE); // blue 34 %
  static const Color glassBorderDark = Color(0x40A9C8FF); // ice-blue 25 %

  /// Fill for glass panels placed on light backgrounds.
  static const Color glassFillLight = Color(0xB3FFFFFF); // white 70 %
  static const Color glassBorderLight = Color(0x80FFFFFF); // white 50 %

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16C784);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF3B5C); // SOS, destructive
  static const Color info = cyan;
}
