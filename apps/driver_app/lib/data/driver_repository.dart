import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// All database access for the driver app. Every call runs as the signed-in
/// driver; the database's row-level rules decide what is allowed.
class DriverRepository {
  DriverRepository(this._db);
  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  // ---------- Account ----------
  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email, password: password);

  /// Returns true when signed in straight away, false when the email must be
  /// confirmed first.
  Future<bool> signUp({required String name, required String email, required String password}) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'role': 'driver'},
    );
    return res.session != null;
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<Profile?> myProfile() async {
    final row = await _db.from('profiles').select().eq('id', _uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  // ---------- Onboarding ----------
  Future<Driver?> myDriver() async {
    final row = await _db.from('drivers').select().eq('id', _uid).maybeSingle();
    return row == null ? null : Driver.fromJson(row);
  }

  Future<void> register(String licenceNumber) =>
      _db.from('drivers').insert({'id': _uid, 'licence_number': licenceNumber});

  Future<void> updateLicence(String licenceNumber) =>
      _db.from('drivers').update({'licence_number': licenceNumber}).eq('id', _uid);

  Future<List<Vehicle>> myVehicles() async {
    final rows = await _db.from('vehicles').select().eq('driver_id', _uid).order('created_at');
    return rows.map(Vehicle.fromJson).toList();
  }

  Future<void> saveVehicle({String? id, required VehicleClass vehicleClass, required String make,
      required String model, required String colour, required int? year, required String plate, required int seats}) {
    final data = {
      'driver_id': _uid, 'class': vehicleClass.name, 'make': make, 'model': model,
      'colour': colour, 'year': year, 'plate_number': plate.toUpperCase(), 'seats': seats,
    };
    return id == null ? _db.from('vehicles').insert(data) : _db.from('vehicles').update(data).eq('id', id);
  }

  Future<List<DriverDocument>> myDocuments() async {
    final rows = await _db.from('driver_documents').select().eq('driver_id', _uid).order('created_at');
    return rows.map(DriverDocument.fromJson).toList();
  }

  /// Uploads into the private bucket at `<driver id>/<type>-<time>.<ext>`.
  Future<void> uploadDocument(DocumentType type, Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = switch (ext) {
      'png' => 'image/png', 'webp' => 'image/webp', 'pdf' => 'application/pdf', _ => 'image/jpeg',
    };
    final path = '$_uid/${type.db}-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('driver-documents')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    await _db.from('driver_documents').insert({'driver_id': _uid, 'type': type.db, 'storage_path': path});
  }

  // ---------- Driving ----------
  Future<void> setOnline(bool online) => _db.from('drivers').update({'is_online': online}).eq('id', _uid);

  Future<void> reportLocation(double lat, double lng, double? heading, double? speedKmh) =>
      _db.from('driver_locations').upsert({
        'driver_id': _uid,
        'location': 'SRID=4326;POINT($lng $lat)',
        'heading_deg': (heading == null || heading < 0) ? null : heading % 360,
        'speed_kmh': (speedKmh == null || speedKmh < 0) ? null : speedKmh,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<List<RideRequest>> openRequests() async {
    final rows = await _db.rpc('open_ride_requests', params: {'p_radius_m': 8000}) as List;
    return rows.cast<Map<String, dynamic>>().map(RideRequest.fromJson).toList();
  }

  Future<void> acceptRide(String rideId) => _db.rpc('accept_ride', params: {'p_ride_id': rideId});

  Future<void> makeOffer(String rideId, int amountKobo, int etaMinutes) => _db.from('fare_offers').insert({
        'ride_id': rideId, 'driver_id': _uid, 'amount_kobo': amountKobo, 'eta_minutes': etaMinutes,
      });

  Future<void> withdrawOffer(String offerId) => _db.rpc('withdraw_offer', params: {'p_offer_id': offerId});

  Future<List<MyOffer>> myPendingOffers() async {
    final rows = await _db.from('fare_offers').select().eq('driver_id', _uid).eq('status', 'pending');
    return rows.map(MyOffer.fromJson).toList();
  }

  Future<Trip?> activeTrip() async {
    final row = await _db.from('rides').select().eq('driver_id', _uid)
        .inFilter('status', ['accepted', 'driver_arrived', 'in_progress'])
        .order('accepted_at', ascending: false).limit(1).maybeSingle();
    return row == null ? null : Trip.fromJson(row);
  }

  /// Passenger first name and rating for a trip (never their phone).
  Future<({String name, double rating})> passengerFor(String rideId) async {
    final rows = await _db.rpc('ride_party', params: {'p_ride_id': rideId}) as List;
    if (rows.isEmpty) return (name: 'Passenger', rating: 5.0);
    final r = rows.first as Map<String, dynamic>;
    return (name: (r['passenger_name'] as String?) ?? 'Passenger',
        rating: (r['passenger_rating'] as num?)?.toDouble() ?? 5.0);
  }

  Future<void> advanceTrip(String rideId, String status) =>
      _db.rpc('advance_ride', params: {'p_ride_id': rideId, 'p_status': status});

  Future<void> cancelTrip(String rideId, String reason) =>
      _db.rpc('cancel_ride', params: {'p_ride_id': rideId, 'p_reason': reason});

  Future<void> ratePassenger(String rideId, int stars) async {
    final ride = await _db.from('rides').select('passenger_id').eq('id', rideId).single();
    await _db.from('ratings').insert({
      'ride_id': rideId, 'rater_id': _uid, 'ratee_id': ride['passenger_id'], 'stars': stars,
    });
  }

  Future<List<Trip>> completedTrips({int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();
    final rows = await _db.from('rides').select().eq('driver_id', _uid).eq('status', 'completed')
        .gte('completed_at', since).order('completed_at', ascending: false).limit(500);
    return rows.map(Trip.fromJson).toList();
  }

  // ---------- Live updates ----------
  RealtimeChannel watchMine(void Function() onChange) => _db
      .channel('driver-$_uid-${DateTime.now().millisecondsSinceEpoch}')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'drivers',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: _uid),
          callback: (_) => onChange())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'rides',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'driver_id', value: _uid),
          callback: (_) => onChange())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'fare_offers',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'driver_id', value: _uid),
          callback: (_) => onChange())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'driver_documents',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'driver_id', value: _uid),
          callback: (_) => onChange())
      .subscribe();

  Future<void> unwatch(RealtimeChannel c) => _db.removeChannel(c);
}
