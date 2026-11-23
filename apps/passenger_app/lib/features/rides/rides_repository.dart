import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../map/map_data.dart';
import 'ride_models.dart';

/// Rides on Supabase, as the signed-in passenger. All changes go through the
/// database's checked functions and row-level rules.
class RidesRepository {
  RidesRepository(this._db);
  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  static String _point(GeoPoint p) => 'SRID=4326;POINT(${p.lng} ${p.lat})';

  Future<String> requestRide({
    required Place pickup,
    required Place dropoff,
    required RideOption option,
    required TripEstimate estimate,
    required int estimatedKobo,
    int? offeredKobo,
  }) async {
    final row = await _db.from('rides').insert({
      'passenger_id': _uid,
      'vehicle_class': option.db,
      'pricing_mode': offeredKobo == null ? 'fixed' : 'negotiable',
      'pickup_location': _point(pickup.location),
      'pickup_address': '${pickup.name}, ${pickup.address}',
      'dropoff_location': _point(dropoff.location),
      'dropoff_address': '${dropoff.name}, ${dropoff.address}',
      'distance_m': (estimate.distanceKm * 1000).round(),
      'duration_s': estimate.durationMin * 60,
      'estimated_fare_kobo': estimatedKobo,
      'offered_fare_kobo': offeredKobo,
      'payment_method': 'cash',
    }).select('id').single();
    return row['id'] as String;
  }

  Future<PassengerRide> ride(String id) async =>
      PassengerRide.fromJson(await _db.from('rides').select().eq('id', id).single());

  /// The newest ride that's still in progress, to resume after a restart.
  Future<PassengerRide?> activeRide() async {
    final row = await _db.from('rides').select().eq('passenger_id', _uid)
        .inFilter('status', ['requested', 'accepted', 'driver_arrived', 'in_progress'])
        .order('requested_at', ascending: false).limit(1).maybeSingle();
    return row == null ? null : PassengerRide.fromJson(row);
  }

  Future<List<PassengerRide>> history() async {
    final rows = await _db.from('rides').select().eq('passenger_id', _uid)
        .order('requested_at', ascending: false).limit(50);
    return rows.map(PassengerRide.fromJson).toList();
  }

  Future<List<DriverOffer>> offers(String rideId) async {
    final rows = await _db.rpc('offers_for_ride', params: {'p_ride_id': rideId}) as List;
    return rows.cast<Map<String, dynamic>>().map(DriverOffer.fromJson).toList();
  }

  Future<void> acceptOffer(String offerId) => _db.rpc('accept_offer', params: {'p_offer_id': offerId});

  Future<void> cancel(String rideId, String reason) =>
      _db.rpc('cancel_ride', params: {'p_ride_id': rideId, 'p_reason': reason});

  Future<AssignedDriver?> driver(String rideId) async {
    final rows = await _db.rpc('ride_party', params: {'p_ride_id': rideId}) as List;
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    if (r['driver_name'] == null) return null;
    return AssignedDriver(
      name: r['driver_name'] as String,
      rating: (r['driver_rating'] as num?)?.toDouble() ?? 5,
      vehicle: [r['vehicle_colour'], r['vehicle_make'], r['vehicle_model']].whereType<String>().join(' '),
      plate: (r['plate_number'] as String?) ?? '',
    );
  }

  Future<void> rateDriver(PassengerRide ride, int stars, String? comment) => _db.from('ratings').insert({
        'ride_id': ride.id, 'rater_id': _uid, 'ratee_id': ride.driverId, 'stars': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });

  Future<void> sos(PassengerRide ride) => _db.from('sos_alerts').insert({
        'user_id': _uid,
        'ride_id': ride.id,
        if (ride.pickup != null) 'location': _point(ride.pickup!),
        'note': 'SOS pressed in the passenger app',
      });

  /// Calls [onChange] whenever this ride or its offers change.
  RealtimeChannel watch(String rideId, void Function() onChange) => _db
      .channel('ride-$rideId-${DateTime.now().millisecondsSinceEpoch}')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'rides',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: rideId),
          callback: (_) => onChange())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'fare_offers',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'ride_id', value: rideId),
          callback: (_) => onChange())
      .subscribe();

  Future<void> unwatch(RealtimeChannel c) => _db.removeChannel(c);
}

/// Real cars on the Home map: anonymous positions of approved, online
/// drivers within 3 km, refreshed every few seconds.
class SupabaseNearbyDrivers implements NearbyDriversSource {
  SupabaseNearbyDrivers(this._db, {this.interval = const Duration(seconds: 5)});
  final SupabaseClient _db;
  final Duration interval;

  @override
  Stream<List<NearbyDriver>> watch(GeoPoint around) {
    late final StreamController<List<NearbyDriver>> controller;
    Timer? timer;
    Future<void> load() async {
      try {
        final rows = await _db.rpc('nearby_drivers', params: {'p_lat': around.lat, 'p_lng': around.lng}) as List;
        if (!controller.isClosed) {
          controller.add([
            for (final r in rows.cast<Map<String, dynamic>>())
              NearbyDriver(
                id: r['driver_ref'] as String,
                location: GeoPoint((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
                headingDeg: (r['heading_deg'] as num?)?.toDouble() ?? 0,
              ),
          ]);
        }
      } catch (_) {/* keep the last positions; retry next tick */}
    }

    controller = StreamController<List<NearbyDriver>>(
      onListen: () {
        load();
        timer = Timer.periodic(interval, (_) => load());
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }
}

/// Places: the Abuja catalogue for search and the pickup spot, with Home /
/// Work saved to the passenger's account and recents from their rides.
class SupabasePlacesRepository extends DemoPlacesRepository {
  SupabasePlacesRepository(this._db) : super(latency: Duration.zero);
  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<Map<SavedPlaceSlot, Place>> savedPlaces() async {
    final uid = _uid;
    if (uid == null) return const {};
    final rows = await _db.from('saved_places').select().eq('user_id', uid).inFilter('slot', ['home', 'work']);
    return {
      for (final r in rows)
        SavedPlaceSlot.values.byName(r['slot'] as String): Place(
          id: 'saved-${r['id']}',
          name: r['name'] as String,
          address: r['address'] as String,
          location: parseEwkbPoint(r['location'] as String?) ?? DemoPlacesRepository.currentSpot.location,
        ),
    };
  }

  @override
  Future<void> savePlace(SavedPlaceSlot slot, Place place) async {
    final uid = _uid;
    if (uid == null) return;
    final row = {
      'user_id': uid, 'slot': slot.name, 'name': place.name, 'address': place.address,
      'location': 'SRID=4326;POINT(${place.location.lng} ${place.location.lat})',
    };
    final existing = await _db.from('saved_places').select('id').eq('user_id', uid).eq('slot', slot.name).maybeSingle();
    if (existing == null) {
      await _db.from('saved_places').insert(row);
    } else {
      await _db.from('saved_places').update(row).eq('id', existing['id'] as String);
    }
  }

  @override
  Future<List<Place>> recentDestinations() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _db.from('rides').select('id, dropoff_address, dropoff_location')
        .eq('passenger_id', uid).order('requested_at', ascending: false).limit(15);
    final seen = <String>{};
    final out = <Place>[];
    for (final r in rows) {
      final full = r['dropoff_address'] as String;
      if (!seen.add(full)) continue;
      final comma = full.indexOf(', ');
      out.add(Place(
        id: 'recent-${r['id']}',
        name: comma > 0 ? full.substring(0, comma) : full,
        address: comma > 0 ? full.substring(comma + 2) : '',
        location: parseEwkbPoint(r['dropoff_location'] as String?) ?? DemoPlacesRepository.currentSpot.location,
      ));
      if (out.length == 5) break;
    }
    return out;
  }

  @override
  Future<void> addRecent(Place place) async {/* recents come from ride history */}
}
