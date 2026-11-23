import 'package:flutter/material.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_typography.dart';

/// The Rent A Ride "R" mark: an italic R with speed stripes trailing to the
/// left and a dashed road lane running down its leg.
///
/// Geometry matches `brand/rar_mark_*.svg` exactly (same 512-unit grid, see
/// `brand/tools/build_logo.py`), drawn in code so it is crisp at any size and
/// costs no asset bytes.
class RarLogo extends StatelessWidget {
  const RarLogo({super.key, this.size = 40, this.color = RarColors.white});

  final double size;

  /// Colour of the letterform. Stripes always use the brand blues; the lane
  /// dashes use navy on a light R and white on a dark R.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rent A Ride logo',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RarLogoPainter(color)),
      ),
    );
  }
}

class _RarLogoPainter extends CustomPainter {
  _RarLogoPainter(this.color);

  final Color color;

  // Square crop of the 512 grid that tightly frames the mark.
  static const double _viewX = 50;
  static const double _viewY = 72;
  static const double _viewSize = 368;

  static const double _skew = -0.17453292519943295; // -10°

  static final Path _r = Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(168, 104)
    ..lineTo(304, 104)
    ..cubicTo(376, 104, 420, 146, 420, 206)
    ..cubicTo(420, 256, 390, 292, 342, 304)
    ..lineTo(424, 408)
    ..lineTo(340, 408)
    ..lineTo(266, 310)
    ..lineTo(238, 310)
    ..lineTo(238, 408)
    ..lineTo(168, 408)
    ..close()
    // Counter (the hole in the bowl).
    ..moveTo(238, 162)
    ..lineTo(298, 162)
    ..cubicTo(330, 162, 348, 180, 348, 206)
    ..cubicTo(348, 232, 330, 250, 298, 250)
    ..lineTo(238, 250)
    ..close();

  // Speed stripes: (x, y, width), height 30, fully rounded.
  static const _stripes = <(double, double, double)>[
    (98, 146, 52),
    (58, 211, 92),
    (104, 276, 46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _viewSize;
    canvas
      ..save()
      ..scale(s, s)
      ..translate(-_viewX, -_viewY)
      ..translate(46, 0)
      ..transform(Matrix4.skewX(_skew).storage);

    final stripePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x5900C8FF), RarColors.cyan, RarColors.royal],
        stops: [0, 0.45, 1],
      ).createShader(const Rect.fromLTWH(40, 0, 110, 1));
    for (final (x, y, w) in _stripes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, 30),
          const Radius.circular(15),
        ),
        stripePaint,
      );
    }

    canvas.drawPath(_r, Paint()..color = color);

    // Dashed road lane down the leg.
    final laneColor = color.computeLuminance() > 0.5
        ? RarColors.navy
        : RarColors.white;
    final lane = Paint()
      ..color = laneColor
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const from = Offset(303, 316);
    const to = Offset(382, 404);
    final total = (to - from).distance;
    final dir = (to - from) / total;
    for (var d = 0.0; d < total; d += 27) {
      final end = d + 14 > total ? total : d + 14;
      canvas.drawLine(from + dir * d, from + dir * end, lane);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RarLogoPainter oldDelegate) => oldDelegate.color != color;
}

/// Logo + "Rent A Ride" wordmark, with an optional tagline beneath.
class RarWordmark extends StatelessWidget {
  const RarWordmark({
    super.key,
    this.logoSize = 40,
    this.fontSize = 22,
    this.subtitle,
    this.onDark = true,
  });

  final double logoSize;
  final double fontSize;
  final String? subtitle;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final base = onDark ? RarColors.white : RarColors.navy;
    final accent = onDark ? const Color(0xFF2F86FF) : RarColors.royal;

    return Semantics(
      label: 'Rent A Ride${subtitle == null ? '' : ', $subtitle'}',
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RarLogo(size: logoSize, color: base),
          SizedBox(width: logoSize * 0.2),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Rent A ',
                        style: TextStyle(color: base),
                      ),
                      TextSpan(
                        text: 'Ride',
                        style: TextStyle(color: accent),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RarTypography.title.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RarTypography.caption.copyWith(
                      color: onDark
                          ? RarColors.textOnDarkSecondary
                          : RarColors.textSecondary,
                      fontSize: fontSize * 0.45,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
