import 'package:flutter/material.dart';

import '../glass/glass_container.dart';
import '../tokens/rar_colors.dart';
import '../tokens/rar_effects.dart';
import '../tokens/rar_spacing.dart';
import '../tokens/rar_typography.dart';

/// Glass pill with an optional leading icon, e.g. "Safe • Reliable •
/// Affordable".
class PillBadge extends StatelessWidget {
  const PillBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      strong: true,
      shadow: false,
      blur: 12,
      borderRadius: RarRadius.pillShape,
      padding: const EdgeInsets.symmetric(
        horizontal: RarSpacing.md,
        vertical: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: RarColors.cyan),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RarTypography.caption.copyWith(color: RarColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding pagination dots. The active dot stretches into a pill.
///
/// When [onDotTap] is provided each dot is a tappable target (48×48 hit
/// area) that jumps to that page.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.index,
    this.onDotTap,
    this.activeColor = RarColors.royal,
    this.inactiveColor = const Color(0x66FFFFFF),
  });

  final int count;
  final int index;
  final ValueChanged<int>? onDotTap;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == index;
          final dot = AnimatedContainer(
            duration: RarMotion.medium,
            curve: RarMotion.standard,
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? activeColor : inactiveColor,
              borderRadius: RarRadius.pillShape,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
          if (onDotTap == null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: dot,
            );
          }
          return Semantics(
            button: true,
            selected: active,
            label: 'Go to page ${i + 1}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onDotTap!(i),
              child: SizedBox(
                height: 32,
                width: active ? 34 : 20,
                child: Center(child: dot),
              ),
            ),
          );
        }),
      ),
    );
  }
}
