import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:rar_design_system/rar_design_system.dart';

import '../../core/config/google_config.dart';
import 'map_data.dart';
import 'ride_map.dart';

/// The home dashboard map.
///
/// Shows a real Google map when a Maps SDK key is configured, otherwise the
/// built-in drawn map, with the same pickup, live drivers, destination and
/// route either way. [recenter] and [zoomBy] work on both.
class DashboardMap extends ConsumerStatefulWidget {
  const DashboardMap({
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
  ConsumerState<DashboardMap> createState() => DashboardMapState();
}

class DashboardMapState extends ConsumerState<DashboardMap> {
  final _drawn = GlobalKey<RideMapState>();
  gm.GoogleMapController? _google;
  gm.BitmapDescriptor? _carIcon;

  static gm.LatLng _ll(GeoPoint p) => gm.LatLng(p.lat, p.lng);

  @override
  void initState() {
    super.initState();
    _buildCarIcon().then((icon) {
      if (mounted) setState(() => _carIcon = icon);
    });
  }

  @override
  void didUpdateWidget(DashboardMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) _fitGoogle();
  }

  void recenter() {
    _drawn.currentState?.recenter();
    _fitGoogle();
  }

  void zoomBy(double factor) {
    _drawn.currentState?.zoomBy(factor);
    _google?.animateCamera(gm.CameraUpdate.zoomBy(math.log(factor) / math.ln2));
  }

  void _fitGoogle() {
    final map = _google;
    if (map == null) return;
    final d = widget.destination;
    if (d == null) {
      map.animateCamera(gm.CameraUpdate.newLatLngZoom(_ll(widget.origin), 15));
      return;
    }
    final a = widget.origin;
    final b = d.location;
    map.animateCamera(
      gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(
          southwest: gm.LatLng(math.min(a.lat, b.lat), math.min(a.lng, b.lng)),
          northeast: gm.LatLng(math.max(a.lat, b.lat), math.max(a.lng, b.lng)),
        ),
        56,
      ),
    );
  }

  /// A small top-down car, drawn once and used for every driver marker.
  static Future<gm.BitmapDescriptor> _buildCarIcon() async {
    const w = 16.0, h = 28.0, scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, 14, 26),
        const Radius.circular(5),
      ),
      Paint()..color = RarColors.navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 6, 10, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF7FB4FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 19, 10, 3.5),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF4C83D9),
    );
    final image = await recorder.endRecording().toImage(
      (w * scale).round(),
      (h * scale).round(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(
      png!.buffer.asUint8List(),
      width: w,
      height: h,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.drivers.length;
    final d = widget.destination;
    final config = ref.watch(googleConfigProvider);

    final map = switch (config) {
      AsyncData(:final value) when value.mapsConfigured => gm.GoogleMap(
        initialCameraPosition: gm.CameraPosition(
          target: _ll(widget.origin),
          zoom: 15,
        ),
        padding: widget.fitPadding,
        onMapCreated: (c) {
          _google = c;
          _fitGoogle();
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: {
          gm.Marker(
            markerId: const gm.MarkerId('pickup'),
            position: _ll(widget.origin),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(
              gm.BitmapDescriptor.hueAzure,
            ),
            infoWindow: const gm.InfoWindow(title: 'Pickup'),
          ),
          for (final car in widget.drivers)
            gm.Marker(
              markerId: gm.MarkerId(car.id),
              position: _ll(car.location),
              icon: _carIcon ?? gm.BitmapDescriptor.defaultMarker,
              rotation: car.headingDeg,
              flat: true,
              anchor: const Offset(0.5, 0.5),
            ),
          if (d != null)
            gm.Marker(
              markerId: const gm.MarkerId('destination'),
              position: _ll(d.location),
              infoWindow: gm.InfoWindow(title: d.name),
            ),
        },
        polylines: {
          if (d != null)
            gm.Polyline(
              polylineId: const gm.PolylineId('route'),
              points: [_ll(widget.origin), _ll(d.location)],
              color: RarColors.royal,
              width: 5,
            ),
        },
      ),
      AsyncLoading() => const RarShimmer(
        child: SkeletonBox(
          height: double.infinity,
          borderRadius: BorderRadius.zero,
        ),
      ),
      _ => RideMap(
        key: _drawn,
        origin: widget.origin,
        drivers: widget.drivers,
        destination: d,
        places: widget.places,
        fitPadding: widget.fitPadding,
      ),
    };

    return Semantics(
      label:
          'Map. $count ${count == 1 ? 'driver' : 'drivers'} nearby.'
          '${d == null ? '' : ' Route to ${d.name}.'}',
      child: map,
    );
  }
}
