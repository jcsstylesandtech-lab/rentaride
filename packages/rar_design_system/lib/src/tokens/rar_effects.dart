import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'rar_colors.dart';

/// Gradients used across the brand.
abstract final class RarGradients {
  /// Primary action: royal blue with a hint of cyan on the leading edge.
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1A8CFF), RarColors.royal],
  );

  /// Deep navy app background used on welcome / dark screens.
  static const LinearGradient darkBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [RarColors.navy700, RarColors.navy, RarColors.navy950],
    stops: [0.0, 0.45, 1.0],
  );

  /// Light app background: white melting into light blue.
  static const LinearGradient lightBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [RarColors.white, RarColors.background],
  );

  /// Subtle sheen on glass panels.
  static const LinearGradient glassSheenDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x26FFFFFF), Color(0x0AFFFFFF)],
  );

  static const LinearGradient glassSheenLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE6FFFFFF), Color(0x99FFFFFF)],
  );

  /// Icon tiles (feature cards).
  static const LinearGradient iconTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F86FF), RarColors.royal],
  );

  /// Brand text highlight (e.g. "Your Choice.").
  static const LinearGradient accentText = LinearGradient(
    colors: [RarColors.cyan, Color(0xFF3AA0FF)],
  );
}

/// Soft shadows — the reference uses diffuse, low-contrast elevation.
abstract final class RarShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x14061B49), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x1F061B49), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Glow under primary buttons.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(color: Color(0x660866FF), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// Glass panels on dark backgrounds.
  static const List<BoxShadow> glassDark = [
    BoxShadow(color: Color(0x33000820), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Motion tokens.
abstract final class RarMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration entrance = Duration(milliseconds: 700);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
}
