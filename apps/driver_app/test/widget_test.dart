import 'package:flutter_test/flutter_test.dart';
import 'package:rent_a_ride_driver/core/format.dart';
import 'package:rent_a_ride_driver/data/models.dart';

void main() {
  test('naira formats kobo with thousands separators', () {
    expect(naira(200000), '₦2,000');
    expect(naira(123456789), '₦1,234,568');
    expect(naira(null), '₦0');
  });

  test('friendly errors', () {
    expect(friendlyError(Exception('AuthException(message: Invalid login credentials, statusCode: 400)')),
        'Wrong email or password.');
  });

  test('ride request parses open_ride_requests() rows', () {
    final r = RideRequest.fromJson({
      'ride_id': 'r1', 'vehicle_class': 'economy', 'pricing_mode': 'negotiable',
      'pickup_address': 'Banex Plaza', 'pickup_lat': 9.079, 'pickup_lng': 7.47,
      'dropoff_address': 'Jabi Lake Mall', 'distance_m': 5100, 'estimated_fare_kobo': 210000,
      'offered_fare_kobo': 180000, 'pickup_distance_m': 233.5, 'passenger_first_name': 'Ada',
      'passenger_rating': 4.9, 'requested_at': '2026-11-23T10:00:00Z',
    });
    expect(r.negotiable, isTrue);
    expect(r.offeredFare, 180000);
    expect(r.passengerName, 'Ada');
  });
}
