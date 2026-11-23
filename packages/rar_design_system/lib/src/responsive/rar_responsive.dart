import 'package:flutter/widgets.dart';

/// Screen-size classes used to adapt layouts.
///
/// Heights matter as much as widths on phones: budget Android devices with
/// on-screen navigation bars often leave less than 600 logical pixels.
enum RarHeightClass {
  /// < 640 dp — e.g. 320×568, 360×600 with system bars.
  compact,

  /// 640–779 dp — most mid-range Android phones, iPhone SE (2nd/3rd gen).
  regular,

  /// ≥ 780 dp — modern tall phones and tablets.
  tall,
}

abstract final class RarResponsive {
  /// Maximum width of phone-style content on tablets / large screens.
  static const double maxContentWidth = 480;

  static RarHeightClass heightClassOf(double height) {
    if (height < 640) return RarHeightClass.compact;
    if (height < 780) return RarHeightClass.regular;
    return RarHeightClass.tall;
  }

  /// Horizontal gutter: tighter on narrow phones.
  static double gutterFor(double width) => width < 350 ? 16 : 20;

  /// Text scale clamp: honours the user's accessibility setting but caps it
  /// so dense mobility UIs (fares, ETAs) remain usable.
  static TextScaler clampTextScaler(TextScaler scaler, {double max = 1.3}) =>
      scaler.clamp(minScaleFactor: 0.85, maxScaleFactor: max);
}

/// Centres its child and limits it to [RarResponsive.maxContentWidth], so
/// phone layouts don't stretch awkwardly on tablets.
class RarContentWidth extends StatelessWidget {
  const RarContentWidth({
    super.key,
    required this.child,
    this.maxWidth = RarResponsive.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
