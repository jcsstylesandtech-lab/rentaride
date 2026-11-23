import 'package:geolocator/geolocator.dart';

import 'google_places.dart';
import 'map_data.dart';

/// Real pickup and search, on top of [base] for saved places and recents:
/// - pickup: the phone's GPS position, named after the nearest place;
/// - search: Google Places suggestions (popular Abuja places when empty).
/// Falls back to [base] when location is off or no Google key is set.
class LivePlacesRepository implements PlacesRepository {
  LivePlacesRepository(this.base, this._google);

  final PlacesRepository base;
  final Future<GooglePlacesClient?> Function() _google;
  GeoPoint? _here;

  @override
  Future<Place> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _fallback();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return _fallback();
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      final here = GeoPoint(pos.latitude, pos.longitude);
      _here = here;
      final named = await (await _google())?.nearest(here).catchError((_) => null);
      return named ??
          Place(
            id: 'current',
            name: 'Current location',
            address: '${here.lat.toStringAsFixed(5)}, ${here.lng.toStringAsFixed(5)}',
            location: here,
          );
    } catch (_) {
      return _fallback();
    }
  }

  Future<Place> _fallback() async {
    final p = await base.currentLocation();
    _here = p.location;
    return Place(id: p.id, name: '${p.name} (location off)', address: p.address, location: p.location);
  }

  @override
  Future<List<Place>> search(String query) async {
    final q = query.trim();
    final google = await _google();
    if (q.length < 2 || google == null) return base.search(q);
    try {
      return await google.autocomplete(q, _here ?? DemoPlacesRepository.currentSpot.location);
    } catch (_) {
      return base.search(q); // offline or quota: use the built-in list
    }
  }

  @override
  Future<Place> resolve(Place place) async {
    if (!place.needsLookup) return place;
    final google = await _google();
    if (google == null) throw StateError('Places search is not available');
    return google.details(place);
  }

  @override
  Future<List<Place>> recentDestinations() => base.recentDestinations();
  @override
  Future<void> addRecent(Place place) => base.addRecent(place);
  @override
  Future<Map<SavedPlaceSlot, Place>> savedPlaces() => base.savedPlaces();
  @override
  Future<void> savePlace(SavedPlaceSlot slot, Place place) => base.savePlace(slot, place);
}
