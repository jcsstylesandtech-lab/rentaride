import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../data/models.dart';

/// Map card on the Drive tab: the driver's own position, nearby request
/// pickups while online, and pickup → drop-off during a trip.
class DriveMap extends StatefulWidget {
  const DriveMap({super.key, required this.me, required this.requests, required this.trip, this.height = 230});
  final ({double lat, double lng})? me;
  final List<RideRequest> requests;
  final Trip? trip;
  final double height;

  @override
  State<DriveMap> createState() => _DriveMapState();
}

class _DriveMapState extends State<DriveMap> {
  static const _abuja = LatLng(9.0790, 7.4700);
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant DriveMap old) {
    super.didUpdateWidget(old);
    if (old.trip?.id != widget.trip?.id || old.trip?.status != widget.trip?.status ||
        (old.me == null && widget.me != null)) {
      _fit();
    }
  }

  List<LatLng> get _focus {
    final t = widget.trip;
    final pts = <LatLng>[];
    if (widget.me != null) pts.add(LatLng(widget.me!.lat, widget.me!.lng));
    if (t != null) {
      final target = t.status == 'in_progress' ? t.dropoff : t.pickup;
      if (target != null) pts.add(LatLng(target.lat, target.lng));
      if (t.status == 'in_progress' && t.pickup != null) pts.add(LatLng(t.pickup!.lat, t.pickup!.lng));
    }
    return pts;
  }

  Future<void> _fit() async {
    final c = _controller;
    final pts = _focus;
    if (c == null || pts.isEmpty) return;
    if (pts.length == 1) {
      await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    double minLat = pts.first.latitude, maxLat = minLat, minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    await c.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 48));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final markers = <Marker>{
      if (t?.pickup != null)
        Marker(markerId: const MarkerId('pickup'), position: LatLng(t!.pickup!.lat, t.pickup!.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: 'Pickup', snippet: t.pickupAddress)),
      if (t?.dropoff != null)
        Marker(markerId: const MarkerId('dropoff'), position: LatLng(t!.dropoff!.lat, t.dropoff!.lng),
            infoWindow: InfoWindow(title: 'Drop-off', snippet: t.dropoffAddress)),
      if (t == null)
        for (final r in widget.requests)
          Marker(markerId: MarkerId('req-${r.id}'), position: LatLng(r.pickupLat, r.pickupLng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
              infoWindow: InfoWindow(title: r.passengerName, snippet: r.pickupAddress)),
    };
    final polylines = <Polyline>{
      if (t?.pickup != null && t?.dropoff != null)
        Polyline(polylineId: const PolylineId('route'), width: 5, color: RarColors.cyan,
            points: [LatLng(t!.pickup!.lat, t.pickup!.lng), LatLng(t.dropoff!.lat, t.dropoff!.lng)]),
    };
    final start = widget.me == null ? _abuja : LatLng(widget.me!.lat, widget.me!.lng);

    return ClipRRect(
      borderRadius: RarRadius.card,
      child: SizedBox(
        height: widget.height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: start, zoom: 14.5),
          style: _darkStyle,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          markers: markers,
          polylines: polylines,
          onMapCreated: (c) {
            _controller = c;
            _fit();
          },
        ),
      ),
    );
  }
}

const _darkStyle = '''[
 {"elementType":"geometry","stylers":[{"color":"#0b2a6b"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#9fb3d9"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#061b49"}]},
 {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#0d3278"}]},
 {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0e3a5e"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#173f8c"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1f56b8"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#061b49"}]},
 {"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';
