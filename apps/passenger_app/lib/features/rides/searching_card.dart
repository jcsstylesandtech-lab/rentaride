import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

import 'ride_models.dart';

/// Same rule as the database's `search_radius_m`: 2 km, +1.5 km every 30 s,
/// up to 10 km.
int searchRadiusM(int secondsWaiting) =>
    math.min(2000 + 1500 * (math.max(secondsWaiting, 0) ~/ 30), 10000);

/// What the passenger sees while we look for a driver or rider: a radar
/// that pulses out from the pickup, the area being searched, how many
/// matching drivers are in it, and how long it has been.
class SearchingCard extends StatefulWidget {
  const SearchingCard({super.key, required this.ride, required this.status, required this.fetchedAt});
  final PassengerRide ride;
  final SearchStatus? status;

  /// When [status] was fetched, so the clock keeps running between polls.
  final DateTime fetchedAt;

  @override
  State<SearchingCard> createState() => _SearchingCardState();
}

class _SearchingCardState extends State<SearchingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "reduce motion": keep a still radar instead of a pulsing one.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0.6;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  int get _seconds {
    final s = widget.status;
    if (s == null) return DateTime.now().difference(widget.ride.requestedAt).inSeconds;
    return s.secondsWaiting + DateTime.now().difference(widget.fetchedAt).inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _seconds;
    final radiusKm = searchRadiusM(seconds) / 1000;
    final count = widget.status?.driversInRange;
    final who = widget.ride.courier; // driver | rider
    final expired = seconds >= 900;
    final clock = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

    final String headline;
    final String detail;
    if (expired) {
      headline = 'No $who accepted in time';
      detail = 'Cancel and request again, or try a different option.';
    } else if (count == null) {
      headline = 'Looking for a $who near you';
      detail = 'Sending your request to ${who}s close to your pickup…';
    } else if (count == 0) {
      headline = 'Still searching';
      detail = 'No ${who}s free within ${_km(radiusKm)} yet. The search area grows every 30 seconds.';
    } else {
      headline = '$count ${who}${count == 1 ? '' : 's'} can see your request';
      detail = 'Searching within ${_km(radiusKm)} of your pickup. The first to accept gets the job.';
    }

    final icon = widget.ride.delivery?.icon ?? widget.ride.option.icon;
    return Semantics(
      liveRegion: true,
      label: '$headline. $detail Waiting $clock.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(RarSpacing.lg),
          decoration: BoxDecoration(
            color: RarColors.white,
            borderRadius: RarRadius.card,
            border: Border.all(color: RarColors.outlineLight),
          ),
          child: Column(children: [
            SizedBox(
              height: 190,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => CustomPaint(
                  painter: _RadarPainter(progress: _pulse.value, active: !expired),
                  child: Center(
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: expired ? null : RarGradients.primaryButton,
                        color: expired ? RarColors.outlineLight : null,
                        boxShadow: [BoxShadow(color: RarColors.royal.withValues(alpha: 0.35), blurRadius: 18)],
                      ),
                      child: Icon(icon, color: RarColors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: RarSpacing.md),
            Text(headline, textAlign: TextAlign.center, style: RarTypography.title.copyWith(color: RarColors.navy)),
            const SizedBox(height: 4),
            Text(detail, textAlign: TextAlign.center,
                style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
            const SizedBox(height: RarSpacing.md),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Pill(icon: Icons.timer_outlined, text: clock),
              const SizedBox(width: RarSpacing.sm),
              _Pill(icon: Icons.radar_rounded, text: _km(radiusKm)),
              if (count != null) ...[
                const SizedBox(width: RarSpacing.sm),
                _Pill(icon: icon, text: '$count nearby'),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  static String _km(double km) => '${km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: RarColors.background, borderRadius: RarRadius.pillShape),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: RarColors.royal),
          const SizedBox(width: 4),
          Text(text, style: RarTypography.caption.copyWith(color: RarColors.navy, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Three rings travelling outwards and fading, over faint fixed guide rings.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.active});
  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = RarColors.royal.withValues(alpha: 0.10);
    for (final f in [0.45, 0.7, 0.95]) {
      canvas.drawCircle(c, maxR * f, guide);
    }
    if (!active) return;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1;
      final r = 34 + (maxR - 34) * t;
      canvas.drawCircle(c, r, Paint()..color = RarColors.royal.withValues(alpha: 0.18 * (1 - t)));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = RarColors.cyan.withValues(alpha: 0.55 * (1 - t)));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress || old.active != active;
}
