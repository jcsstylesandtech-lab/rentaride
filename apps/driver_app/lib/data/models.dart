import 'dart:typed_data';

enum DriverStatus { pending, approved, rejected, suspended }

/// What the driver does on Rent A Ride (drivers.service_type).
enum ServiceType {
  ride('Ride driver', 'Carry passengers in your car'),
  dispatch('Dispatch rider', 'Deliver small packages on a motorbike'),
  delivery('Delivery driver', 'Move parcels and goods with a car or van');

  const ServiceType(this.label, this.hint);
  final String label;
  final String hint;
}

enum VehicleClass { economy, comfort, premium, suv, motorcycle }

enum DocumentType {
  driversLicence('drivers_licence', "Driver's licence", true),
  nationalId('national_id', 'National ID (NIN slip or card)', true),
  vehicleRegistration('vehicle_registration', 'Vehicle registration', true),
  insurance('insurance', 'Insurance certificate', true),
  roadworthiness('roadworthiness', 'Roadworthiness certificate', false),
  vehiclePhoto('vehicle_photo', 'Photo of your vehicle', true),
  profilePhoto('profile_photo', 'Clear photo of your face', true);

  const DocumentType(this.db, this.label, this.required);
  final String db;
  final String label;
  final bool required;

  static DocumentType fromDb(String v) => values.firstWhere((t) => t.db == v);
}

class Profile {
  const Profile({required this.id, required this.fullName, required this.email, required this.phone,
      required this.role, required this.ratingAvg, required this.ratingCount});
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final double ratingAvg;
  final int ratingCount;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        fullName: (j['full_name'] as String?) ?? '',
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        role: j['role'] as String,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble() ?? 5,
        ratingCount: (j['rating_count'] as int?) ?? 0,
      );
}

class Driver {
  const Driver({required this.id, required this.status, required this.licenceNumber,
      required this.isOnline, required this.rejectionReason, this.serviceType = ServiceType.ride});
  final String id;
  final DriverStatus status;
  final ServiceType serviceType;
  final String? licenceNumber;
  final bool isOnline;
  final String? rejectionReason;

  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
        id: j['id'] as String,
        status: DriverStatus.values.byName(j['status'] as String),
        serviceType: ServiceType.values.asNameMap()[j['service_type']] ?? ServiceType.ride,
        licenceNumber: j['licence_number'] as String?,
        isOnline: j['is_online'] as bool? ?? false,
        rejectionReason: j['rejection_reason'] as String?,
      );
}

class Vehicle {
  const Vehicle({required this.id, required this.vehicleClass, required this.make, required this.model,
      required this.colour, required this.year, required this.plateNumber, required this.seats, required this.review});
  final String id;
  final VehicleClass vehicleClass;
  final String make;
  final String model;
  final String colour;
  final int? year;
  final String plateNumber;
  final int seats;
  final String review;

  String get title => '$colour $make $model${year == null ? '' : ' $year'}';

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        vehicleClass: VehicleClass.values.byName(j['class'] as String),
        make: j['make'] as String,
        model: j['model'] as String,
        colour: j['colour'] as String,
        year: j['year'] as int?,
        plateNumber: j['plate_number'] as String,
        seats: j['seats'] as int,
        review: j['review'] as String,
      );
}

class DriverDocument {
  const DriverDocument({required this.id, required this.type, required this.review, required this.note, required this.createdAt});
  final String id;
  final DocumentType type;
  final String review;
  final String? note;
  final DateTime createdAt;

  factory DriverDocument.fromJson(Map<String, dynamic> j) => DriverDocument(
        id: j['id'] as String,
        type: DocumentType.fromDb(j['type'] as String),
        review: j['review'] as String,
        note: j['reviewer_note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// An open request near the driver, from `open_ride_requests()`.
class RideRequest {
  const RideRequest({required this.id, required this.vehicleClass, required this.negotiable,
      required this.pickupAddress, required this.pickupLat, required this.pickupLng, required this.dropoffAddress,
      required this.distanceM, required this.estimatedFare, required this.offeredFare,
      required this.pickupDistanceM, required this.passengerName, required this.passengerRating, required this.requestedAt});
  final String id;
  final String vehicleClass;
  final bool negotiable;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final int? distanceM;
  final int estimatedFare;
  final int? offeredFare;
  final double pickupDistanceM;
  final String passengerName;
  final double passengerRating;
  final DateTime requestedAt;

  factory RideRequest.fromJson(Map<String, dynamic> j) => RideRequest(
        id: j['ride_id'] as String,
        vehicleClass: j['vehicle_class'] as String,
        negotiable: j['pricing_mode'] == 'negotiable',
        pickupAddress: j['pickup_address'] as String,
        pickupLat: (j['pickup_lat'] as num).toDouble(),
        pickupLng: (j['pickup_lng'] as num).toDouble(),
        dropoffAddress: j['dropoff_address'] as String,
        distanceM: j['distance_m'] as int?,
        estimatedFare: (j['estimated_fare_kobo'] as num).toInt(),
        offeredFare: (j['offered_fare_kobo'] as num?)?.toInt(),
        pickupDistanceM: (j['pickup_distance_m'] as num).toDouble(),
        passengerName: (j['passenger_first_name'] as String?)?.trim().isNotEmpty == true
            ? j['passenger_first_name'] as String
            : 'Passenger',
        passengerRating: (j['passenger_rating'] as num?)?.toDouble() ?? 5,
        requestedAt: DateTime.parse(j['requested_at'] as String),
      );
}

/// A ride assigned to this driver.
class Trip {
  const Trip({required this.id, required this.status, required this.pickupAddress, required this.dropoffAddress,
      this.pickup, this.dropoff,
      required this.fare, required this.negotiable, required this.paymentMethod, required this.distanceM,
      required this.completedAt, required this.requestedAt});
  final String id;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final ({double lat, double lng})? pickup;
  final ({double lat, double lng})? dropoff;
  final int fare;
  final bool negotiable;
  final String paymentMethod;
  final int? distanceM;
  final DateTime? completedAt;
  final DateTime requestedAt;

  bool get isActive => const {'accepted', 'driver_arrived', 'in_progress'}.contains(status);

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        status: j['status'] as String,
        pickupAddress: j['pickup_address'] as String,
        dropoffAddress: j['dropoff_address'] as String,
        pickup: parsePoint(j['pickup_location'] as String?),
        dropoff: parsePoint(j['dropoff_location'] as String?),
        fare: ((j['final_fare_kobo'] ?? j['agreed_fare_kobo'] ?? j['estimated_fare_kobo']) as num).toInt(),
        negotiable: j['pricing_mode'] == 'negotiable',
        paymentMethod: j['payment_method'] as String,
        distanceM: j['distance_m'] as int?,
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String),
        requestedAt: DateTime.parse(j['requested_at'] as String),
      );
}

class MyOffer {
  const MyOffer({required this.id, required this.rideId, required this.amount, required this.status});
  final String id;
  final String rideId;
  final int amount;
  final String status;

  factory MyOffer.fromJson(Map<String, dynamic> j) => MyOffer(
        id: j['id'] as String,
        rideId: j['ride_id'] as String,
        amount: (j['amount_kobo'] as num).toInt(),
        status: j['status'] as String,
      );
}

/// Reads a PostGIS point as the API returns it (hex EWKB) → (lat, lng).
({double lat, double lng})? parsePoint(String? hex) {
  if (hex == null || hex.length < 42) return null;
  try {
    final bytes = Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
    final data = ByteData.sublistView(bytes);
    final endian = bytes[0] == 1 ? Endian.little : Endian.big;
    final type = data.getUint32(1, endian);
    final offset = (type & 0x20000000) != 0 ? 9 : 5; // skip SRID when present
    return (lng: data.getFloat64(offset, endian), lat: data.getFloat64(offset + 8, endian));
  } catch (_) {
    return null;
  }
}
