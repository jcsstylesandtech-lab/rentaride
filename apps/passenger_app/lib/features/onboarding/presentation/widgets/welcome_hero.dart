import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

/// Top-of-screen hero for the welcome screen.
///
/// Renders an illustrated night-time city with a glowing ride route. If a
/// [photoAsset] is supplied it is layered over the illustration (so there
/// is never a blank frame while it decodes). A gradient fades the hero into
/// the navy background so the headline beneath stays readable.
class WelcomeHero extends StatelessWidget {
  const WelcomeHero({super.key, this.photoAsset});

  final String? photoAsset;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: CityScenePainter()),
          ),
          if (photoAsset != null)
            Image.asset(
              photoAsset!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          // Fade into the background colour.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33061B49),
                  Color(0x00061B49),
                  Color(0xB3061B49),
                  RarColors.navy,
                ],
                stops: [0.0, 0.3, 0.62, 0.9],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stylised city skyline at dusk with light trails and a route to a pin.
/// Deterministic (seeded) so it looks identical on every launch.
class CityScenePainter extends CustomPainter {
  const CityScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    // ── Sky ────────────────────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A2C78), Color(0xFF1655C8), Color(0xFF0B2A6B)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Glow behind the skyline.
    canvas.drawCircle(
      Offset(w * 0.62, horizon * 0.86),
      w * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                RarColors.cyan.withValues(alpha: 0.35),
                RarColors.cyan.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.62, horizon * 0.86),
                radius: w * 0.55,
              ),
            ),
    );

    final rnd = math.Random(7);

    // ── Far skyline ─────────────────────────────────────────────────────
    _skyline(
      canvas,
      rnd,
      width: w,
      base: horizon,
      minH: h * 0.10,
      maxH: h * 0.34,
      color: const Color(0xFF1B4FA8).withValues(alpha: 0.75),
      windows: false,
    );

    // A couple of landmark towers.
    final towerPaint = Paint()..color = const Color(0xFF123A8F);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.68, horizon - h * 0.48, w * 0.07, h * 0.48),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      towerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.712, horizon - h * 0.56, w * 0.006, h * 0.08),
      towerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.80, horizon - h * 0.40, w * 0.09, h * 0.40),
      towerPaint,
    );

    // ── Near skyline with lit windows ──────────────────────────────────
    _skyline(
      canvas,
      rnd,
      width: w,
      base: horizon + h * 0.02,
      minH: h * 0.08,
      maxH: h * 0.24,
      color: const Color(0xFF0B2A6B),
      windows: true,
    );

    // ── Ground / road ───────────────────────────────────────────────────
    final groundTop = horizon + h * 0.02;
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, w, h - groundTop),
      Paint()..color = RarColors.navy700,
    );

    final vanishing = Offset(w * 0.55, groundTop);
    final road = Path()
      ..moveTo(vanishing.dx - w * 0.03, groundTop)
      ..lineTo(vanishing.dx + w * 0.03, groundTop)
      ..lineTo(w * 1.1, h)
      ..lineTo(-w * 0.1, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF082056));

    // Light trails converging on the horizon.
    void trail(double endX, Color color, double width) {
      final p = Path()
        ..moveTo(vanishing.dx, groundTop)
        ..quadraticBezierTo(
          vanishing.dx + (endX - vanishing.dx) * 0.3,
          groundTop + (h - groundTop) * 0.55,
          endX,
          h,
        );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2.6
          ..color = color.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = color.withValues(alpha: 0.45),
      );
    }

    trail(w * 0.12, RarColors.cyan, 2.2);
    trail(w * 0.38, RarColors.royal, 2.6);
    trail(w * 0.78, const Color(0xFF7FDBFF), 1.6);
    trail(w * 1.02, RarColors.royal, 2.0);

    // ── Ride route with destination pin ─────────────────────────────────
    final start = Offset(w * 0.16, horizon - h * 0.06);
    // Keep the pin below the header row (logo + Skip).
    final pin = Offset(w * 0.80, math.max(h * 0.26, 120));
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        w * 0.36,
        horizon - h * 0.30,
        w * 0.52,
        h * 0.14,
        pin.dx,
        pin.dy + 16,
      );
    _dashed(
      canvas,
      route,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = RarColors.cyan.withValues(alpha: 0.9),
    );

    // Origin dot.
    canvas.drawCircle(
      start,
      10,
      Paint()..color = RarColors.royal.withValues(alpha: 0.35),
    );
    canvas.drawCircle(start, 5, Paint()..color = RarColors.white);
    canvas.drawCircle(start, 3, Paint()..color = RarColors.royal);

    // Pin.
    canvas.drawCircle(
      pin + const Offset(0, 16),
      12,
      Paint()
        ..color = RarColors.cyan.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final pinPath = Path()
      ..moveTo(pin.dx, pin.dy + 18)
      ..cubicTo(
        pin.dx - 4,
        pin.dy + 10,
        pin.dx - 11,
        pin.dy + 4,
        pin.dx - 11,
        pin.dy - 4,
      )
      ..arcToPoint(
        Offset(pin.dx + 11, pin.dy - 4),
        radius: const Radius.circular(11),
      )
      ..cubicTo(
        pin.dx + 11,
        pin.dy + 4,
        pin.dx + 4,
        pin.dy + 10,
        pin.dx,
        pin.dy + 18,
      )
      ..close();
    canvas.drawPath(pinPath, Paint()..color = RarColors.cyan);
    canvas.drawCircle(
      pin - const Offset(0, 4),
      4.2,
      Paint()..color = RarColors.navy,
    );
  }

  void _skyline(
    Canvas canvas,
    math.Random rnd, {
    required double width,
    required double base,
    required double minH,
    required double maxH,
    required Color color,
    required bool windows,
  }) {
    final body = Paint()..color = color;
    final lit = Paint()
      ..color = const Color(0xFFBFE9FF).withValues(alpha: 0.55);
    final litWarm = Paint()
      ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.45);

    var x = -8.0;
    while (x < width) {
      final bw = 18 + rnd.nextDouble() * 34;
      final bh = minH + rnd.nextDouble() * (maxH - minH);
      final rect = Rect.fromLTWH(x, base - bh, bw, bh);
      canvas.drawRect(rect, body);

      if (windows) {
        for (var wy = rect.top + 6; wy < rect.bottom - 6; wy += 7) {
          for (var wx = rect.left + 4; wx < rect.right - 5; wx += 6) {
            final r = rnd.nextDouble();
            if (r < 0.28) {
              canvas.drawRect(
                Rect.fromLTWH(wx, wy, 2.4, 3),
                r < 0.08 ? litWarm : lit,
              );
            }
          }
        }
      }
      x += bw + 2 + rnd.nextDouble() * 4;
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 8.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(CityScenePainter oldDelegate) => false;
}
