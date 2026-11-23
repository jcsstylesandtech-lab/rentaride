import 'package:flutter/painting.dart';

/// 4-pt spacing scale.
abstract final class RarSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal page gutter on phones.
  static const double gutter = 20;

  /// Minimum interactive target (Material / WCAG guidance).
  static const double minTouchTarget = 48;

  /// Height of primary buttons.
  static const double buttonHeight = 54;
}

/// Corner radii. The reference uses generously rounded cards and buttons.
abstract final class RarRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius pillShape = BorderRadius.all(Radius.circular(pill));
}
