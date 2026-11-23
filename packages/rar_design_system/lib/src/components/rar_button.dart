import 'package:flutter/material.dart';

import '../glass/glass_container.dart';
import '../tokens/rar_colors.dart';
import '../tokens/rar_effects.dart';
import '../tokens/rar_spacing.dart';
import '../tokens/rar_typography.dart';

enum RarButtonVariant {
  /// Royal-blue gradient with glow. One per screen.
  primary,

  /// Translucent glass, for secondary actions on dark backgrounds.
  glass,

  /// Bordered, for secondary actions on light backgrounds.
  outline,
}

/// Brand button with press feedback, loading and disabled states.
///
/// When [onPressed] is null, or [isLoading] is true, the button is disabled
/// and announces itself as such to screen readers.
class RarButton extends StatefulWidget {
  const RarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RarButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.height = RarSpacing.buttonHeight,
    this.semanticLabel,
  });

  const RarButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    String? semanticLabel,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         leadingIcon: leadingIcon,
         trailingIcon: trailingIcon,
         isLoading: isLoading,
         semanticLabel: semanticLabel,
       );

  const RarButton.glass({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    String? semanticLabel,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: RarButtonVariant.glass,
         leadingIcon: leadingIcon,
         trailingIcon: trailingIcon,
         isLoading: isLoading,
         semanticLabel: semanticLabel,
       );

  const RarButton.outline({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? leadingIcon,
    IconData? trailingIcon,
    bool isLoading = false,
    String? semanticLabel,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: RarButtonVariant.outline,
         leadingIcon: leadingIcon,
         trailingIcon: trailingIcon,
         isLoading: isLoading,
         semanticLabel: semanticLabel,
       );

  final String label;
  final VoidCallback? onPressed;
  final RarButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final double height;
  final String? semanticLabel;

  @override
  State<RarButton> createState() => _RarButtonState();
}

class _RarButtonState extends State<RarButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_enabled && value != _pressed) setState(() => _pressed = value);
  }

  Color get _foreground => switch (widget.variant) {
    RarButtonVariant.primary || RarButtonVariant.glass => RarColors.white,
    RarButtonVariant.outline => RarColors.navy,
  };

  @override
  Widget build(BuildContext context) {
    final radius = RarRadius.button;
    final fg = _foreground;

    final content = AnimatedSwitcher(
      duration: RarMotion.fast,
      child: widget.isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leadingIcon != null) ...[
                  Icon(widget.leadingIcon, size: 20, color: fg),
                  const SizedBox(width: RarSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RarTypography.label.copyWith(color: fg),
                  ),
                ),
                if (widget.trailingIcon != null) ...[
                  const SizedBox(width: RarSpacing.sm),
                  Icon(widget.trailingIcon, size: 20, color: fg),
                ],
              ],
            ),
    );

    final inkLayer = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: radius,
        onTap: _enabled ? widget.onPressed : null,
        onHighlightChanged: _setPressed,
        splashColor: RarColors.white.withValues(alpha: 0.12),
        highlightColor: RarColors.white.withValues(alpha: 0.06),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RarSpacing.xl),
            child: content,
          ),
        ),
      ),
    );

    final Widget surface = switch (widget.variant) {
      RarButtonVariant.primary => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RarGradients.primaryButton,
          borderRadius: radius,
          boxShadow: _enabled ? RarShadows.primaryGlow : null,
        ),
        child: inkLayer,
      ),
      RarButtonVariant.glass => GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: radius,
        shadow: false,
        blur: 12,
        child: inkLayer,
      ),
      RarButtonVariant.outline => DecoratedBox(
        decoration: BoxDecoration(
          color: RarColors.white,
          borderRadius: radius,
          border: Border.all(color: RarColors.outlineLight, width: 1.2),
        ),
        child: inkLayer,
      ),
    };

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: RarMotion.fast,
        curve: RarMotion.standard,
        child: AnimatedOpacity(
          opacity: widget.onPressed == null ? 0.5 : 1,
          duration: RarMotion.fast,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: surface,
          ),
        ),
      ),
    );
  }
}
