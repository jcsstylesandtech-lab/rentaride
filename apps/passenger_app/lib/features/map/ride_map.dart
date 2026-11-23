import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

import 'map_data.dart';

/// Illustrated, interactive city map: drag to pan, pinch to zoom.
///
/// Used when no Google Maps key is configured. Shows the pickup point,
/// live nearby drivers, place labels and, once a destination is chosen, the
/// route. Positions are real coordinates; the street grid is drawn.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    required this.origin,
    required this.drivers,
    this.destination,
    this.places = const [],
    this.fitPadding = EdgeInsets.zero,
  });

  final GeoPoint origin;
  final List<NearbyDriver> drivers;
  final Place? destination;
  final List<Place> places;

  /// Parts of the map covered by overlays; the camera fits inside the rest.
  final EdgeInsets fitPadding;

  @override
  State<RideMap> createState() => RideMapState();
}

class RideMapState extends State<RideMap> with TickerProviderStateMixin {
  static const double _defaultMpp = 5.0; // metres per logical pixel
  static const double _minMpp = 0.8;
  static const double _maxMpp = 160;

  math.Point<double> _center = const math.Point(0, 0);
  double _mpp = _defaultMpp;
  Size _size = Size.zero;

  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..addListener(_onCameraTick);
  math.Point<double> _fromCenter = const math.Point(0, 0);
  math.Point<double> _toCenter = const math.Point(0, 0);
  double _fromMpp = _defaultMpp;
  double _toMpp = _defaultMpp;

  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
    value: 1,
  );
  List<NearbyDriver> _fromDrivers = const [];

  math.Point<double>? _gestureStartCenter;
  double _gestureStartMpp = _defaultMpp;
  bool _userMoved = false;
  bool _needsFit = true;

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination ||
        oldWidget.origin != widget.origin) {
      _userMoved = false;
      _fit(animate: true);
    }
    if (!identical(oldWidget.drivers, widget.drivers)) {
      _fromDrivers = _interpolatedDrivers(oldWidget.drivers);
      if (MediaQuery.disableAnimationsOf(context)) {
        _move.value = 1;
      } else {
        _move.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    _move.dispose();
    super.dispose();
  }

  void recenter() {
    _userMoved = false;
    _fit(animate: true);
  }

  void zoomBy(double factor) {
    _userMoved = true;
    _animateTo(_center, (_mpp / factor).clamp(_minMpp, _maxMpp));
  }

  void _onCameraTick() {
    final t = Curves.easeInOutCubic.transform(_camera.value);
    setState(() {
      _center = math.Point(
        _fromCenter.x + (_toCenter.x - _fromCenter.x) * t,
        _fromCenter.y + (_toCenter.y - _fromCenter.y) * t,
      );
      _mpp = _fromMpp * math.pow(_toMpp / _fromMpp, t);
    });
  }

  void _animateTo(math.Point<double> center, double mpp) {
    if (MediaQuery.disableAnimationsOf(context) || _size == Size.zero) {
      setState(() {
        _center = center;
        _mpp = mpp;
      });
      return;
    }
    _fromCenter = _center;
    _fromMpp = _mpp;
    _toCenter = center;
    _toMpp = mpp;
    _camera.forward(from: 0);
  }

  void _fit({required bool animate}) {
    if (_size == Size.zero) {
      _needsFit = true;
      return;
    }
    final pad = widget.fitPadding;
    final visW = math.max(80.0, _size.width - pad.horizontal);
    final visH = math.max(80.0, _size.height - pad.vertical);
    final dv = Offset(
      pad.left + visW / 2 - _size.width / 2,
      pad.top + visH / 2 - _size.height / 2,
    );

    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    double mpp = _defaultMpp;
    final dest = widget.destination;
    if (dest != null) {
      final d = Geo.toMeters(dest.location, widget.origin);
      minX = math.min(0, d.x);
      maxX = math.max(0, d.x);
      minY = math.min(0, d.y);
      maxY = math.max(0, d.y);
      mpp = math.max((maxX - minX) / (visW - 80), (maxY - minY) / (visH - 80));
      mpp = mpp.clamp(_minMpp, _maxMpp);
    }
    final center = math.Point(
      (minX + maxX) / 2 - dv.dx * mpp,
      (minY + maxY) / 2 - dv.dy * mpp,
    );
    if (animate) {
      _animateTo(center, mpp);
    } else {
      _center = center;
      _mpp = mpp;
    }
  }

  List<NearbyDriver> _interpolatedDrivers(List<NearbyDriver> target) {
    final t = Curves.easeInOut.transform(_move.value);
    final from = {for (final d in _fromDrivers) d.id: d};
    return [
      for (final d in target)
        if (from[d.id] case final f?)
          NearbyDriver(
            id: d.id,
            location: GeoPoint(
              f.location.lat + (d.location.lat - f.location.lat) * t,
              f.location.lng + (d.location.lng - f.location.lng) * t,
            ),
            headingDeg: _lerpAngle(f.headingDeg, d.headingDeg, t),
          )
        else
          d,
    ];
  }

  static double _lerpAngle(double a, double b, double t) {
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    return a + diff * t;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size != _size) {
          _size = size;
          if (_needsFit || !_userMoved) {
            _needsFit = false;
            _fit(animate: false);
          }
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) {
            _camera.stop();
            _gestureStartCenter = _center;
            _gestureStartMpp = _mpp;
          },
          onScaleUpdate: (d) {
            if (_gestureStartCenter == null) return;
            _userMoved = true;
            setState(() {
              _mpp = (_gestureStartMpp / d.scale).clamp(_minMpp, _maxMpp);
              _center = math.Point(
                _center.x - d.focalPointDelta.dx * _mpp,
                _center.y - d.focalPointDelta.dy * _mpp,
              );
            });
          },
          onScaleEnd: (_) => _gestureStartCenter = null,
          child: AnimatedBuilder(
            animation: _move,
            builder: (context, _) => CustomPaint(
              size: size,
              painter: _MapPainter(
                origin: widget.origin,
                center: _center,
                mpp: _mpp,
                drivers: _interpolatedDrivers(widget.drivers),
                destination: widget.destination,
                places: widget.places,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.origin,
    required this.center,
    required this.mpp,
    required this.drivers,
    required this.destination,
    required this.places,
  });

  final GeoPoint origin;
  final math.Point<double> center;
  final double mpp;
  final List<NearbyDriver> drivers;
  final Place? destination;
  final List<Place> places;

  /// Abuja's street grid runs roughly 32° off north.
  static const double _gridAngle = -32 * math.pi / 180;

  static const _land = Color(0xFFEAF0F8);
  static const _park = Color(0xFFD3EEDB);
  static const _water = Color(0xFFBFDDF7);
  static const _road = Color(0xFFFFFFFF);
  static const _roadEdge = Color(0xFFD8E1EE);

  late Size _size;

  Offset _screen(math.Point<double> m) => Offset(
    _size.width / 2 + (m.x - center.x) / mpp,
    _size.height / 2 + (m.y - center.y) / mpp,
  );

  Offset _project(GeoPoint p) => _screen(Geo.toMeters(p, origin));

  static math.Point<double> _rotate(math.Point<double> p, double a) =>
      math.Point(
        p.x * math.cos(a) - p.y * math.sin(a),
        p.x * math.sin(a) + p.y * math.cos(a),
      );

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _land);
    _paintAreas(canvas);
    _paintRoads(canvas);
    _paintLabels(canvas);
    _paintRoute(canvas);
    for (final d in drivers) {
      _paintCar(canvas, _project(d.location), d.headingDeg);
    }
    _paintPickup(canvas, _project(origin));
    if (destination != null) _paintDestination(canvas);
  }

  void _paintAreas(Canvas canvas) {
    const cell = 1200.0;
    final halfW = _size.width / 2 * mpp + cell;
    final halfH = _size.height / 2 * mpp + cell;
    final park = Paint()..color = _park;
    if (mpp < 40) {
      for (
        var cx = ((center.x - halfW) / cell).floor();
        cx <= ((center.x + halfW) / cell).ceil();
        cx++
      ) {
        for (
          var cy = ((center.y - halfH) / cell).floor();
          cy <= ((center.y + halfH) / cell).ceil();
          cy++
        ) {
          final h = ((cx * 73856093) ^ (cy * 19349663)) & 0x7fffffff;
          if (h % 5 != 0) continue;
          final w = 260 + (h % 7) * 60.0;
          final ht = 200 + (h % 5) * 70.0;
          final m = math.Point(cx * cell + (h % 300), cy * cell + (h % 400));
          final o = _screen(m);
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(_gridAngle);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, w / mpp, ht / mpp),
              Radius.circular(40 / mpp),
            ),
            park,
          );
          canvas.restore();
        }
      }
    }
    final lake = _project(const GeoPoint(9.0745, 7.4205));
    canvas.save();
    canvas.translate(lake.dx, lake.dy);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 1300 / mpp,
        height: 520 / mpp,
      ),
      Paint()..color = _water,
    );
    canvas.restore();
  }

  void _paintRoads(Canvas canvas) {
    final radius =
        math.sqrt(math.pow(_size.width, 2) + math.pow(_size.height, 2)) /
        2 *
        mpp;
    final c = _rotate(center, -_gridAngle);
    final o = _screen(const math.Point(0, 0));

    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(_gridAngle);
    canvas.scale(1 / mpp);

    void grid(double spacing, double widthPx, {bool edge = false}) {
      if (spacing / mpp < 7) return;
      final w = widthPx * mpp;
      final edgePaint = Paint()
        ..color = _roadEdge
        ..strokeWidth = w + 1.6 * mpp;
      final roadPaint = Paint()
        ..color = _road
        ..strokeWidth = w;
      for (final paint in [if (edge) edgePaint, roadPaint]) {
        for (
          var x = ((c.x - radius) / spacing).floor() * spacing;
          x <= c.x + radius;
          x += spacing
        ) {
          canvas.drawLine(
            Offset(x, c.y - radius),
            Offset(x, c.y + radius),
            paint,
          );
        }
        for (
          var y = ((c.y - radius) / spacing).floor() * spacing;
          y <= c.y + radius;
          y += spacing
        ) {
          canvas.drawLine(
            Offset(c.x - radius, y),
            Offset(c.x + radius, y),
            paint,
          );
        }
      }
    }

    grid(260, 3);
    grid(1300, math.max(5, 22 / mpp).clamp(5, 11).toDouble(), edge: true);
    canvas.restore();
  }

  void _paintLabels(Canvas canvas) {
    if (mpp > 25) return;
    for (final p in places) {
      if (p.id == destination?.id) continue;
      final at = _project(p.location);
      if (!(Offset.zero & _size).inflate(-8).contains(at)) continue;
      canvas.drawCircle(at, 3, Paint()..color = RarColors.textMuted);
      _text(
        canvas,
        p.name,
        at + const Offset(6, -7),
        RarColors.textSecondary,
        10,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double size, {
    bool bold = false,
  }) {
    TextStyle style(Paint? fg, Color? c) => TextStyle(
      fontFamily: RarTypography.fontFamily,
      package: RarTypography.fontPackage,
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      foreground: fg,
      color: c,
    );
    final halo = TextPainter(
      text: TextSpan(
        text: text,
        style: style(
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white,
          null,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);
    final fill = TextPainter(
      text: TextSpan(text: text, style: style(null, color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);
    halo.paint(canvas, at);
    fill.paint(canvas, at);
  }

  /// Follows the street grid: along one axis, then the other.
  List<Offset>? _routePoints() {
    if (destination == null) return null;
    final d = Geo.toMeters(destination!.location, origin);
    final g = _rotate(d, -_gridAngle);
    final corner = _rotate(math.Point(g.x, 0), _gridAngle);
    return [_screen(const math.Point(0, 0)), _screen(corner), _screen(d)];
  }

  void _paintRoute(Canvas canvas) {
    final pts = _routePoints();
    if (pts == null) return;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawPath(path, stroke(Colors.white, 9));
    canvas.drawPath(path, stroke(RarColors.royal, 5));
  }

  void _paintCar(Canvas canvas, Offset at, double headingDeg) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(headingDeg * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -13, 16, 26),
        const Radius.circular(5),
      ),
      Paint()
        ..color = const Color(0x33061B49)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -12, 14, 24),
        const Radius.circular(5),
      ),
      Paint()..color = RarColors.navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -7, 10, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF7FB4FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, 5, 10, 3.5),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF4C83D9),
    );
    canvas.restore();
  }

  void _paintPickup(Canvas canvas, Offset at) {
    canvas.drawCircle(
      at,
      30,
      Paint()..color = RarColors.royal.withValues(alpha: 0.14),
    );
    canvas.drawCircle(at, 11, Paint()..color = Colors.white);
    canvas.drawCircle(at, 7.5, Paint()..color = RarColors.royal);
  }

  void _paintDestination(Canvas canvas) {
    final at = _project(destination!.location);
    final pin = Path()
      ..moveTo(at.dx, at.dy)
      ..cubicTo(
        at.dx - 4,
        at.dy - 8,
        at.dx - 13,
        at.dy - 14,
        at.dx - 13,
        at.dy - 24,
      )
      ..arcToPoint(
        Offset(at.dx + 13, at.dy - 24),
        radius: const Radius.circular(13),
      )
      ..cubicTo(at.dx + 13, at.dy - 14, at.dx + 4, at.dy - 8, at.dx, at.dy)
      ..close();
    canvas.drawPath(
      pin.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x40061B49)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(pin, Paint()..color = RarColors.danger);
    canvas.drawCircle(
      at - const Offset(0, 24),
      5,
      Paint()..color = Colors.white,
    );
    _text(
      canvas,
      destination!.name,
      at + const Offset(14, -30),
      RarColors.navy,
      11,
      bold: true,
    );
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.mpp != mpp ||
      oldDelegate.drivers != drivers ||
      oldDelegate.destination != destination ||
      oldDelegate.places != places ||
      oldDelegate.origin != origin;
}
