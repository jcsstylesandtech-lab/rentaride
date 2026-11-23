import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../core/config/app_config.dart';
import '../../../map/map_data.dart';
import '../../../rides/rides_repository.dart';

/// Supabase when the app is built with its settings, otherwise demo data.
final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => AppConfig.hasBackend
      ? SupabasePlacesRepository(Supabase.instance.client)
      : DemoPlacesRepository(),
);

final nearbyDriversSourceProvider = Provider<NearbyDriversSource>(
  (ref) => AppConfig.hasBackend
      ? SupabaseNearbyDrivers(Supabase.instance.client)
      : const DemoNearbyDrivers(),
);

final ridesRepositoryProvider = Provider<RidesRepository>(
  (ref) => RidesRepository(Supabase.instance.client),
);

/// The passenger's pickup point (current location).
final currentLocationProvider = FutureProvider<Place>(
  (ref) => ref.read(placesRepositoryProvider).currentLocation(),
);

/// Available drivers around the pickup point, updated live.
final nearbyDriversProvider = StreamProvider<List<NearbyDriver>>((ref) {
  final pickup = ref.watch(currentLocationProvider).value;
  if (pickup == null) return const Stream.empty();
  return ref.read(nearbyDriversSourceProvider).watch(pickup.location);
});

final recentDestinationsProvider = FutureProvider<List<Place>>(
  (ref) => ref.read(placesRepositoryProvider).recentDestinations(),
);

final savedPlacesProvider = FutureProvider<Map<SavedPlaceSlot, Place>>(
  (ref) => ref.read(placesRepositoryProvider).savedPlaces(),
);

/// The destination the passenger has chosen, if any.
final destinationProvider = NotifierProvider<DestinationController, Place?>(
  DestinationController.new,
);

class DestinationController extends Notifier<Place?> {
  @override
  Place? build() => null;

  Future<void> choose(Place place) async {
    state = place;
    await ref.read(placesRepositoryProvider).addRecent(place);
    ref.invalidate(recentDestinationsProvider);
  }

  void clear() => state = null;
}

/// Estimate for the chosen trip, once both ends are known.
final tripEstimateProvider = Provider<TripEstimate?>((ref) {
  final pickup = ref.watch(currentLocationProvider).value;
  final destination = ref.watch(destinationProvider);
  if (pickup == null || destination == null) return null;
  return TripEstimate.between(pickup.location, destination.location);
});

Future<void> savePlace(WidgetRef ref, SavedPlaceSlot slot, Place place) async {
  await ref.read(placesRepositoryProvider).savePlace(slot, place);
  ref.invalidate(savedPlacesProvider);
}
