import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_effects.dart';
import '../tokens/rar_spacing.dart';

/// Which background a glass panel sits on.
enum GlassTone { dark, light }

/// App-wide glass rendering settings.
///
/// `BackdropFilter` is one of the most expensive operations on low-end
/// Android GPUs, which are common in the Nigerian market. Wrap the app in a
/// [RarGlassSettings] with `blurEnabled: false` to keep the translucent look
/// without the blur cost (e.g. on battery saver or low-RAM devices).
class RarGlassSettings extends InheritedWidget {
  const RarGlassSettings({
    super.key,
    required super.child,
    this.blurEnabled = true,
  });

  final bool blurEnabled;

  static bool blurOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RarGlassSettings>()
          ?.blurEnabled ??
      true;

  @override
  bool updateShouldNotify(RarGlassSettings oldWidget) =>
      blurEnabled != oldWidget.blurEnabled;
}

/// A translucent "frosted glass" panel — the core surface of the brand.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.tone = GlassTone.dark,
    this.padding = const EdgeInsets.all(RarSpacing.lg),
    this.borderRadius = RarRadius.card,
    this.blur = 18,
    this.strong = false,
    this.shadow = true,
    this.width,
    this.height,
  });

  final Widget child;
  final GlassTone tone;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Blur sigma. Ignored when [RarGlassSettings.blurEnabled] is false.
  final double blur;

  /// Slightly more opaque fill, for panels that need more separation.
  final bool strong;
  final bool shadow;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isDark = tone == GlassTone.dark;
    final blurEnabled = RarGlassSettings.blurOf(context) && blur > 0;

    final fill = isDark
        ? (strong ? RarColors.glassFillDarkStrong : RarColors.glassFillDark)
        : RarColors.glassFillLight;
    // Without blur, raise opacity a little so text stays legible.
    final effectiveFill = blurEnabled
        ? fill
        : Color.lerp(fill, isDark ? RarColors.navy700 : RarColors.white, 0.5)!;

    Widget panel = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        // Fill + sheen in one gradient: brighter top-left edge, like light
        // catching the glass.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveFill.withValues(
              alpha: (effectiveFill.a + (isDark ? 0.08 : 0.15)).clamp(0, 1),
            ),
            effectiveFill,
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark
              ? RarColors.glassBorderDark
              : RarColors.glassBorderLight,
        ),
      ),
      child: child,
    );

    if (blurEnabled) {
      panel = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? (isDark ? RarShadows.glassDark : RarShadows.soft)
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: panel),
    );
  }
}
