import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

// ── Coordinates ──────────────────────────────────────────────────────────

/// A WGS84 coordinate. (Named GeoPoint so it never clashes with Google
/// Maps' own `LatLng`.)
@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

abstract final class Geo {
  /// Great-circle distance in metres.
  static double distanceM(GeoPoint a, GeoPoint b) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) *
            math.cos(rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * 6371000 * math.asin(math.sqrt(h));
  }

  /// Local flat projection in metres around [origin] (x east, y south).
  static math.Point<double> toMeters(GeoPoint p, GeoPoint origin) {
    final x =
        (p.lng - origin.lng) * 111320 * math.cos(origin.lat * math.pi / 180);
    final y = -(p.lat - origin.lat) * 110540;
    return math.Point(x, y);
  }

  static GeoPoint fromMeters(math.Point<double> m, GeoPoint origin) => GeoPoint(
    origin.lat - m.y / 110540,
    origin.lng + m.x / (111320 * math.cos(origin.lat * math.pi / 180)),
  );

  /// Directions in the Google Maps app (or google.com/maps in a browser).
  /// Needs no API key.
  static Uri googleMapsDirections(GeoPoint from, GeoPoint to) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '${from.lat},${from.lng}',
        'destination': '${to.lat},${to.lng}',
        'travelmode': 'driving',
      });
}

/// Trip estimate shown before booking. The binding price will come from
/// the server's pricing rules; this mirrors the default Economy rule.
@immutable
class TripEstimate {
  const TripEstimate({
    required this.distanceKm,
    required this.durationMin,
    required this.economyFareNaira,
  });

  /// Straight-line distance × 1.3 approximates road distance in Abuja.
  factory TripEstimate.between(GeoPoint a, GeoPoint b) {
    final km = Geo.distanceM(a, b) / 1000 * 1.3;
    // ~24 km/h average city speed, plus 3 minutes for pickup.
    final minutes = (km / 24 * 60).round() + 3;
    // Economy: ₦500 base + ₦150/km + ₦20/min, rounded to ₦50.
    final fare = 500 + 150 * km + 20 * minutes;
    return TripEstimate(
      distanceKm: km,
      durationMin: minutes,
      economyFareNaira: (fare / 50).round() * 50,
    );
  }

  final double distanceKm;
  final int durationMin;
  final int economyFareNaira;
}

/// `2400` → `₦2,400`.
String formatNaira(num amount) {
  final s = amount.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '₦$buf';
}

// ── Places ───────────────────────────────────────────────────────────────

@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.needsLookup = false,
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint location;

  /// A search suggestion whose exact coordinates are fetched only when the
  /// rider picks it ([PlacesRepository.resolve]). Until then [location] is
  /// approximate and shouldn't be used for distances.
  final bool needsLookup;

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum SavedPlaceSlot { home, work }

/// Places data. Phase 3 backs this with Google Places through the API
/// (autocomplete is proxied so the Places key never ships in the app).
abstract interface class PlacesRepository {
  Future<Place> currentLocation();
  Future<List<Place>> search(String query);
  Future<List<Place>> recentDestinations();
  Future<void> addRecent(Place place);
  Future<Map<SavedPlaceSlot, Place>> savedPlaces();
  Future<void> savePlace(SavedPlaceSlot slot, Place place);

  /// Exact details for a chosen suggestion (no-op for complete places).
  Future<Place> resolve(Place place);
}

/// Real Abuja landmarks with their coordinates, held in memory until the
/// places API exists.
class DemoPlacesRepository implements PlacesRepository {
  DemoPlacesRepository({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;

  static const currentSpot = Place(
    id: 'current',
    name: 'My current location',
    address: 'Aminu Kano Crescent, Wuse 2, Abuja',
    location: GeoPoint(9.0790, 7.4700),
  );

  static const all = <Place>[
    Place(
      id: 'jabi-lake-mall',
      name: 'Jabi Lake Mall',
      address: 'Bala Sokoto Way, Jabi, Abuja',
      location: GeoPoint(9.0703, 7.4245),
    ),
    Place(
      id: 'nnamdi-azikiwe-airport',
      name: 'Nnamdi Azikiwe International Airport',
      address: 'Airport Road, Abuja',
      location: GeoPoint(9.0068, 7.2632),
    ),
    Place(
      id: 'transcorp-hilton',
      name: 'Transcorp Hilton Abuja',
      address: '1 Aguiyi Ironsi Street, Maitama, Abuja',
      location: GeoPoint(9.0727, 7.4993),
    ),
    Place(
      id: 'banex-plaza',
      name: 'Banex Plaza',
      address: 'Aminu Kano Crescent, Wuse 2, Abuja',
      location: GeoPoint(9.0836, 7.4733),
    ),
    Place(
      id: 'ceddi-plaza',
      name: 'Ceddi Plaza',
      address: 'Tafawa Balewa Way, Central Area, Abuja',
      location: GeoPoint(9.0559, 7.4893),
    ),
    Place(
      id: 'national-hospital',
      name: 'National Hospital Abuja',
      address: 'Plot 132 Central District, Abuja',
      location: GeoPoint(9.0379, 7.4708),
    ),
    Place(
      id: 'millennium-park',
      name: 'Millennium Park',
      address: 'Shehu Shagari Way, Maitama, Abuja',
      location: GeoPoint(9.0700, 7.5150),
    ),
    Place(
      id: 'silverbird-galleria',
      name: 'Silverbird Galleria',
      address: 'Plot 1161 Memorial Drive, Central Area, Abuja',
      location: GeoPoint(9.0490, 7.4880),
    ),
    Place(
      id: 'garki-area-11',
      name: 'Garki Area 11',
      address: 'Garki, Abuja',
      location: GeoPoint(9.0300, 7.4900),
    ),
    Place(
      id: 'nnpc-towers',
      name: 'NNPC Towers',
      address: 'Herbert Macaulay Way, Central Area, Abuja',
      location: GeoPoint(9.0420, 7.4830),
    ),
    Place(
      id: 'unity-fountain',
      name: 'Unity Fountain',
      address: 'Independence Avenue, Maitama, Abuja',
      location: GeoPoint(9.0730, 7.4980),
    ),
    Place(
      id: 'wuse-market',
      name: 'Wuse Market',
      address: 'Wuse Zone 5, Abuja',
      location: GeoPoint(9.0650, 7.4650),
    ),
    Place(
      id: 'gwarinpa-estate',
      name: 'Gwarinpa Estate',
      address: '1st Avenue, Gwarinpa, Abuja',
      location: GeoPoint(9.1100, 7.4050),
    ),
  ];

  final _recent = <Place>[all[0], all[4]];
  final _saved = <SavedPlaceSlot, Place>{};

  Future<void> _network() => Future<void>.delayed(latency);

  @override
  Future<Place> currentLocation() async {
    await _network();
    return currentSpot;
  }

  @override
  Future<List<Place>> search(String query) async {
    await Future<void>.delayed(latency ~/ 3);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final p in all)
        if (p.name.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q))
          p,
    ];
  }

  @override
  Future<List<Place>> recentDestinations() async {
    await _network();
    return List.unmodifiable(_recent);
  }

  @override
  Future<void> addRecent(Place place) async {
    _recent
      ..remove(place)
      ..insert(0, place);
    if (_recent.length > 5) _recent.removeLast();
  }

  @override
  Future<Map<SavedPlaceSlot, Place>> savedPlaces() async {
    await _network();
    return Map.unmodifiable(_saved);
  }

  @override
  Future<void> savePlace(SavedPlaceSlot slot, Place place) async {
    await Future<void>.delayed(latency ~/ 3);
    _saved[slot] = place;
  }

  @override
  Future<Place> resolve(Place place) async => place;
}

// ── Nearby drivers ───────────────────────────────────────────────────────

@immutable
class NearbyDriver {
  const NearbyDriver({
    required this.id,
    required this.location,
    required this.headingDeg,
  });

  final String id;
  final GeoPoint location;

  /// Direction of travel, degrees clockwise from north.
  final double headingDeg;
}

/// Live positions of available drivers. Phase 3: a Socket.IO subscription
/// fed by drivers' GPS. Until then [DemoNearbyDrivers] moves a few cars in
/// loops around the passenger, updating every few seconds.
abstract interface class NearbyDriversSource {
  Stream<List<NearbyDriver>> watch(GeoPoint around);
}

class DemoNearbyDrivers implements NearbyDriversSource {
  const DemoNearbyDrivers({
    this.interval = const Duration(seconds: 4),
    this.count = 7,
  });

  final Duration interval;
  final int count;

  @override
  Stream<List<NearbyDriver>> watch(GeoPoint around) {
    final rnd = math.Random(42);
    final cars = List.generate(count, (i) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      final dist = 250 + rnd.nextDouble() * 1100;
      return (
        center: math.Point(math.cos(angle) * dist, math.sin(angle) * dist),
        radius: 120 + rnd.nextDouble() * 220,
        phase: rnd.nextDouble() * 2 * math.pi,
        speed: (rnd.nextBool() ? 1 : -1) * (0.12 + rnd.nextDouble() * 0.1),
      );
    });

    List<NearbyDriver> at(int tick) => [
      for (final (i, c) in cars.indexed)
        () {
          final a = c.phase + tick * c.speed;
          final pos = math.Point(
            c.center.x + math.cos(a) * c.radius,
            c.center.y + math.sin(a) * c.radius,
          );
          final dx = -math.sin(a) * c.speed.sign;
          final dy = math.cos(a) * c.speed.sign;
          final heading = (math.atan2(dx, -dy) * 180 / math.pi) % 360;
          return NearbyDriver(
            id: 'driver-$i',
            location: Geo.fromMeters(pos, around),
            headingDeg: heading,
          );
        }(),
    ];

    late final StreamController<List<NearbyDriver>> controller;
    Timer? timer;
    var tick = 0;
    controller = StreamController<List<NearbyDriver>>(
      onListen: () {
        controller.add(at(tick));
        timer = Timer.periodic(interval, (_) => controller.add(at(++tick)));
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }
}
