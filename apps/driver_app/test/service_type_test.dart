import 'package:flutter_test/flutter_test.dart';
import 'package:rent_a_ride_driver/data/models.dart';

void main() {
  Map<String, dynamic> row([String? service]) => {
        'id': 'd1', 'status': 'pending', 'licence_number': null, 'is_online': false,
        'rejection_reason': null, 'service_type': ?service,
      };

  test('reads the service a driver chose', () {
    expect(Driver.fromJson(row('dispatch')).serviceType, ServiceType.dispatch);
    expect(Driver.fromJson(row('delivery')).serviceType, ServiceType.delivery);
    expect(Driver.fromJson(row('ride')).serviceType, ServiceType.ride);
  });

  test('older records without a service are ride drivers', () {
    expect(Driver.fromJson(row()).serviceType, ServiceType.ride);
    expect(Driver.fromJson(row('something-new')).serviceType, ServiceType.ride);
  });

  test('delivery jobs and trips carry the package and recipient', () {
    final job = RideRequest.fromJson({
      'ride_id': 'r1', 'service_type': 'dispatch', 'vehicle_class': 'motorcycle', 'pricing_mode': 'fixed',
      'pickup_address': 'A', 'pickup_lat': 9.0, 'pickup_lng': 7.4, 'dropoff_address': 'B', 'distance_m': 5000,
      'estimated_fare_kobo': 140000, 'offered_fare_kobo': null, 'pickup_distance_m': 800.0,
      'passenger_first_name': 'Ada', 'passenger_rating': 4.9, 'requested_at': '2026-11-25T10:00:00Z',
      'package_size': 'small', 'package_note': 'Envelope',
    });
    expect(job.service, ServiceType.dispatch);
    expect(job.packageNote, 'Envelope');

    final trip = Trip.fromJson({
      'id': 'r1', 'status': 'accepted', 'pickup_address': 'A', 'dropoff_address': 'B',
      'estimated_fare_kobo': 140000, 'pricing_mode': 'fixed', 'payment_method': 'cash',
      'requested_at': '2026-11-25T10:00:00Z', 'service_type': 'delivery',
      'recipient_name': 'Ngozi', 'recipient_phone': '+2348031234567', 'package_size': 'large',
    });
    expect(trip.isDelivery, isTrue);
    expect(trip.recipientPhone, '+2348031234567');

    final ride = Trip.fromJson({
      'id': 'r2', 'status': 'accepted', 'pickup_address': 'A', 'dropoff_address': 'B',
      'estimated_fare_kobo': 100000, 'pricing_mode': 'fixed', 'payment_method': 'cash',
      'requested_at': '2026-11-25T10:00:00Z',
    });
    expect(ride.isDelivery, isFalse);
  });
}
