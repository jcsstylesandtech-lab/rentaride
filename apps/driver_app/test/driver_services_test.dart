import 'package:flutter_test/flutter_test.dart';
import 'package:rent_a_ride_driver/data/models.dart';

void main() {
  test('drivers keep their sign-up service until they choose more', () {
    final d = Driver.fromJson({'id': 'x', 'status': 'approved', 'service_type': 'ride'});
    expect(d.services, [ServiceType.ride]);
  });

  test('chosen services are read from the database, unknown values skipped', () {
    final d = Driver.fromJson({'id': 'x', 'status': 'approved', 'service_type': 'ride',
        'services': ['ride', 'delivery', 'teleport']});
    expect(d.services, [ServiceType.ride, ServiceType.delivery]);
  });

  test('each kind of job needs a vehicle that fits it', () {
    expect(ServiceType.dispatch.vehicleClasses, {VehicleClass.motorcycle});
    expect(ServiceType.delivery.vehicleClasses.contains(VehicleClass.economy), isTrue);
    expect(ServiceType.ride.vehicleClasses.contains(VehicleClass.motorcycle), isFalse);
  });
}
