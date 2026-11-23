import 'package:flutter/material.dart';

import '../glass/glass_container.dart';
import '../tokens/rar_colors.dart';
import '../tokens/rar_effects.dart';
import '../tokens/rar_spacing.dart';
import '../tokens/rar_typography.dart';

/// Rounded-square icon on a royal-blue gradient (feature cards, quick
/// actions, home/work shortcuts).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.gradient = RarGradients.iconTile,
    this.iconColor = RarColors.white,
  });

  final IconData icon;
  final double size;
  final Gradient gradient;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400866FF),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.55),
    );
  }
}

/// Glass card with an [IconTile], a title and a short description.
/// Used for the Ride / Delivery / Explore / Safety cards.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Hides the description on very short screens.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: GlassContainer(
        padding: EdgeInsets.zero,
        blur: 14,
        shadow: false,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: RarRadius.card,
            splashColor: RarColors.cyan.withValues(alpha: 0.12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: RarSpacing.minTouchTarget,
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? RarSpacing.sm : 10),
                child: Row(
                  children: [
                    IconTile(icon: icon, size: compact ? 32 : 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RarTypography.titleSmall.copyWith(
                              color: RarColors.white,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: RarTypography.caption.copyWith(
                                color: RarColors.textOnDarkSecondary,
                                fontWeight: FontWeight.w400,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
