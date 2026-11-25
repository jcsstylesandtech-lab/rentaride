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
}
