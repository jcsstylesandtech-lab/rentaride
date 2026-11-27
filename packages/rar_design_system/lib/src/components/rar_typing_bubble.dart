import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_typography.dart';

/// "Support is typing…" bubble: three dots that bounce in turn.
class RarTypingBubble extends StatefulWidget {
  const RarTypingBubble({super.key, required this.label, this.dark = false});

  /// Who is typing, e.g. "Support". Announced to screen readers.
  final String label;

  /// Use on dark backgrounds (driver app).
  final bool dark;

  @override
  State<RarTypingBubble> createState() => _RarTypingBubbleState();
}

class _RarTypingBubbleState extends State<RarTypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "reduce motion": show still dots instead.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.dark ? RarColors.textOnDarkSecondary : RarColors.textMuted;
    return Semantics(
      liveRegion: true,
      label: '${widget.label} is typing',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.dark ? RarColors.glassFillDarkStrong : RarColors.white,
              border: Border.all(color: widget.dark ? RarColors.glassBorderDark : RarColors.outlineLight),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                    child: Transform.translate(
                      offset: Offset(0, -3 * math.max(0, math.sin((_c.value - i * 0.18) * 2 * math.pi))),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('${widget.label} is typing…',
                style: RarTypography.caption.copyWith(fontSize: 11, color: dot)),
          ),
        ]),
      ),
    );
  }
}
