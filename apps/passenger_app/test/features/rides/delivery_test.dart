import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_passenger/features/home/presentation/controllers/home_providers.dart';
import 'package:rent_a_ride_passenger/features/map/map_data.dart';
import 'package:rent_a_ride_passenger/features/rides/delivery_sheet.dart';
import 'package:rent_a_ride_passenger/features/rides/ride_models.dart';
import 'package:rent_a_ride_passenger/features/rides/rides_repository.dart';
import 'package:rent_a_ride_passenger/features/rides/searching_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Records the delivery request, then fails it so the sheet stays open.
class _FakeRides implements RidesRepository {
  final requests = <Map<String, Object?>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String> requestDelivery({
    required Place pickup, required Place dropoff, required DeliveryOption option, required PackageSize size,
    required TripEstimate estimate, required int fareKobo, required String recipientName,
    required String recipientPhone, String? note,
  }) async {
    requests.add({'option': option, 'size': size, 'fare': fareKobo, 'name': recipientName,
        'phone': recipientPhone, 'note': note});
    throw const PostgrestException(message: 'stop here');
  }
}

const _estimate = TripEstimate(distanceKm: 6, durationMin: 18, economyFareNaira: 2000);
const _pickup = Place(id: 'a', name: 'Wuse 2', address: 'Abuja', location: GeoPoint(9.08, 7.47));
const _dropoff = Place(id: 'b', name: 'Garki', address: 'Abuja', location: GeoPoint(9.03, 7.49));

void main() {
  group('prices and rules', () {
    test('bike is cheapest, van dearest; bigger packages cost more', () {
      final bike = DeliveryOption.dispatchBike.fareNaira(_estimate, PackageSize.small);
      final car = DeliveryOption.deliveryCar.fareNaira(_estimate, PackageSize.small);
      final van = DeliveryOption.deliveryVan.fareNaira(_estimate, PackageSize.small);
      expect(bike, 1400);
      expect(bike < car && car < van, isTrue);
      expect(DeliveryOption.deliveryCar.fareNaira(_estimate, PackageSize.large), greaterThan(car));
      for (final f in [bike, car, van]) {
        expect(f % 50, 0);
      }
    });

    test('a bike cannot carry a large package', () {
      expect(DeliveryOption.dispatchBike.carries(PackageSize.large), isFalse);
      expect(DeliveryOption.dispatchBike.carries(PackageSize.medium), isTrue);
      expect(DeliveryOption.deliveryVan.carries(PackageSize.large), isTrue);
    });

    test('search area matches the database rule', () {
      expect(searchRadiusM(0), 2000);
      expect(searchRadiusM(29), 2000);
      expect(searchRadiusM(65), 5000);
      expect(searchRadiusM(600), 10000);
    });

    test('a delivery row reads back as a delivery', () {
      final ride = PassengerRide.fromJson({
        'id': 'r1', 'status': 'requested', 'vehicle_class': 'motorcycle', 'pricing_mode': 'fixed',
        'pickup_address': 'A', 'dropoff_address': 'B', 'estimated_fare_kobo': 140000,
        'requested_at': '2026-11-25T10:00:00Z', 'service_type': 'dispatch',
        'recipient_name': 'Ngozi', 'package_size': 'medium',
      });
      expect(ride.isDelivery, isTrue);
      expect(ride.delivery, DeliveryOption.dispatchBike);
      expect(ride.optionLabel, 'Dispatch bike');
      expect(ride.courier, 'rider');
      expect(ride.packageSize, PackageSize.medium);
    });
  });

  group('send a package sheet', () {
    late _FakeRides repo;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repo = _FakeRides();
      await tester.pumpWidget(ProviderScope(
        overrides: [ridesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: RarTheme.light(),
          home: const Scaffold(body: DeliverySheet(pickup: _pickup, dropoff: _dropoff, estimate: _estimate)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String key, String text) => tester.enterText(
        find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText)), text);

    testWidgets('needs a recipient before sending', (tester) async {
      await open(tester);
      await tap(tester, 'request-delivery');
      expect(find.text("Enter the recipient's name"), findsOneWidget);
      expect(find.text('Enter a Nigerian mobile number, e.g. 0803 123 4567.'), findsOneWidget);
      expect(repo.requests, isEmpty);
    });

    testWidgets('large package moves off the bike; sends name, +234 phone and fare', (tester) async {
      await open(tester);
      await tap(tester, 'size-large');
      expect(find.text('Too small for a large package'), findsOneWidget);
      await type(tester, 'recipient-name', 'Ngozi Okafor');
      await type(tester, 'recipient-phone', '0803 123 4567');
      await type(tester, 'package-note', 'Two boxes');
      await tap(tester, 'request-delivery');
      expect(repo.requests, hasLength(1));
      final r = repo.requests.single;
      expect(r['option'], DeliveryOption.deliveryCar);
      expect(r['size'], PackageSize.large);
      expect(r['phone'], '+2348031234567');
      expect(r['name'], 'Ngozi Okafor');
      expect(r['fare'], DeliveryOption.deliveryCar.fareNaira(_estimate, PackageSize.large) * 100);
      expect(find.text('stop here'), findsOneWidget); // server error is shown, sheet stays
    });
  });

  testWidgets('searching card shows drivers in range and the search area', (tester) async {
    final ride = PassengerRide.fromJson({
      'id': 'r1', 'status': 'requested', 'vehicle_class': 'economy', 'pricing_mode': 'fixed',
      'pickup_address': 'A', 'dropoff_address': 'B', 'estimated_fare_kobo': 200000,
      'requested_at': DateTime.now().toUtc().toIso8601String(),
    });
    await tester.pumpWidget(MaterialApp(
      theme: RarTheme.light(),
      home: Scaffold(body: SearchingCard(
        ride: ride,
        status: const SearchStatus(radiusM: 5000, driversInRange: 3, secondsWaiting: 70, expiresInS: 830),
        fetchedAt: DateTime.now(),
      )),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('3 drivers can see your request'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);
    expect(find.text('1:10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop the pulse and clock
  });
}
