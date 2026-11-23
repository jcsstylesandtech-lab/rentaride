import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../map/map_data.dart';

/// Ride types a passenger can book. Prices scale the Economy estimate.
enum RideOption {
  economy('economy', 'Economy', 'Affordable everyday rides', Icons.directions_car_rounded, 1.0, 4),
  comfort('comfort', 'Comfort', 'Newer cars, extra legroom', Icons.airline_seat_recline_extra_rounded, 1.3, 4),
  premium('premium', 'Premium', 'Top-rated drivers, luxury cars', Icons.workspace_premium_rounded, 1.8, 4),
  suv('suv', 'SUV', 'Room for 6 and luggage', Icons.airport_shuttle_rounded, 1.6, 6),
  motorcycle('motorcycle', 'Okada', 'Beat traffic, solo rider', Icons.two_wheeler_rounded, 0.6, 1);

  const RideOption(this.db, this.label, this.blurb, this.icon, this.multiplier, this.seats);
  final String db;
  final String label;
  final String blurb;
  final IconData icon;
  final double multiplier;
  final int seats;

  /// Fixed fare in naira for this option, rounded to ₦50.
  int fareNaira(TripEstimate e) => ((e.economyFareNaira * multiplier) / 50).round() * 50;

  static RideOption fromDb(String v) => values.firstWhere((o) => o.db == v, orElse: () => economy);
}

/// A ride as the passenger sees it.
class PassengerRide {
  const PassengerRide({required this.id, required this.status, required this.option, required this.negotiable,
      required this.pickupAddress, required this.dropoffAddress, required this.estimatedKobo,
      required this.offeredKobo, required this.agreedKobo, required this.finalKobo, required this.driverId,
      required this.requestedAt, required this.cancelReason, required this.pickup});
  final String id;
  final String status;
  final RideOption option;
  final bool negotiable;
  final String pickupAddress;
  final String dropoffAddress;
  final int estimatedKobo;
  final int? offeredKobo;
  final int? agreedKobo;
  final int? finalKobo;
  final String? driverId;
  final DateTime requestedAt;
  final String? cancelReason;
  final GeoPoint? pickup;

  bool get isOpen => const {'requested', 'accepted', 'driver_arrived', 'in_progress'}.contains(status);
  bool get hasDriver => const {'accepted', 'driver_arrived', 'in_progress', 'completed'}.contains(status);
  int get fareKobo => finalKobo ?? agreedKobo ?? offeredKobo ?? estimatedKobo;

  factory PassengerRide.fromJson(Map<String, dynamic> j) => PassengerRide(
        id: j['id'] as String,
        status: j['status'] as String,
        option: RideOption.fromDb(j['vehicle_class'] as String),
        negotiable: j['pricing_mode'] == 'negotiable',
        pickupAddress: j['pickup_address'] as String,
        dropoffAddress: j['dropoff_address'] as String,
        estimatedKobo: (j['estimated_fare_kobo'] as num).toInt(),
        offeredKobo: (j['offered_fare_kobo'] as num?)?.toInt(),
        agreedKobo: (j['agreed_fare_kobo'] as num?)?.toInt(),
        finalKobo: (j['final_fare_kobo'] as num?)?.toInt(),
        driverId: j['driver_id'] as String?,
        requestedAt: DateTime.parse(j['requested_at'] as String),
        cancelReason: j['cancel_reason'] as String?,
        pickup: parseEwkbPoint(j['pickup_location'] as String?),
      );
}

/// A driver's offer on a negotiable ride (from `offers_for_ride`).
class DriverOffer {
  const DriverOffer({required this.id, required this.amountKobo, required this.etaMinutes, required this.driverName,
      required this.rating, required this.ratingCount, required this.vehicle});
  final String id;
  final int amountKobo;
  final int? etaMinutes;
  final String driverName;
  final double rating;
  final int ratingCount;
  final String vehicle;

  factory DriverOffer.fromJson(Map<String, dynamic> j) => DriverOffer(
        id: j['offer_id'] as String,
        amountKobo: (j['amount_kobo'] as num).toInt(),
        etaMinutes: j['eta_minutes'] as int?,
        driverName: (j['driver_first_name'] as String?) ?? 'Driver',
        rating: (j['driver_rating'] as num?)?.toDouble() ?? 5,
        ratingCount: (j['driver_rating_count'] as int?) ?? 0,
        vehicle: [j['vehicle_colour'], j['vehicle_make'], j['vehicle_model']].whereType<String>().join(' '),
      );
}

/// The assigned driver and car (from `ride_party`) — never a phone number.
class AssignedDriver {
  const AssignedDriver({required this.name, required this.rating, required this.vehicle, required this.plate});
  final String name;
  final double rating;
  final String vehicle;
  final String plate;
}

String nairaKobo(int kobo) => formatNaira(kobo / 100);

/// Reads a PostGIS point as the API returns it (hex EWKB).
GeoPoint? parseEwkbPoint(String? hex) {
  if (hex == null || hex.length < 42) return null;
  try {
    final bytes = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    final data = ByteData.sublistView(bytes);
    final endian = bytes[0] == 1 ? Endian.little : Endian.big;
    final offset = (data.getUint32(1, endian) & 0x20000000) != 0 ? 9 : 5;
    return GeoPoint(data.getFloat64(offset + 8, endian), data.getFloat64(offset, endian));
  } catch (_) {
    return null;
  }
}
