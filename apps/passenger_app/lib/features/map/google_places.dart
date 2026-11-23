import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'map_data.dart';

/// Google Places API (New) over HTTPS. Requests carry [_identity] (iOS bundle
/// ID, or Android package + certificate) so an app-restricted key works.
class GooglePlacesClient {
  GooglePlacesClient(this._key, this._identity, {http.Client? client}) : _http = client ?? http.Client();

  final String _key;
  final Map<String, String> _identity;
  final http.Client _http;
  static const _base = 'https://places.googleapis.com/v1';

  /// One token per search → pick, so Google bills it as a single session.
  String _session = _newToken();
  static String _newToken() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Map<String, String> _headers([String? fieldMask]) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _key,
        ..._identity,
        'X-Goog-FieldMask': ?fieldMask,
      };

  /// Suggestions for [query], biased to 30 km around [near], Nigeria only.
  Future<List<Place>> autocomplete(String query, GeoPoint near) async {
    final res = await _http.post(Uri.parse('$_base/places:autocomplete'),
        headers: _headers(),
        body: jsonEncode({
          'input': query,
          'sessionToken': _session,
          'includedRegionCodes': ['ng'],
          'locationBias': {
            'circle': {
              'center': {'latitude': near.lat, 'longitude': near.lng},
              'radius': 30000.0,
            },
          },
        }));
    if (res.statusCode != 200) throw PlacesException(res.statusCode, res.body);
    final suggestions = (jsonDecode(res.body)['suggestions'] as List?) ?? const [];
    return [
      for (final s in suggestions)
        if (s['placePrediction'] case final Map<String, dynamic> p)
          Place(
            id: 'g:${p['placeId']}',
            name: (p['structuredFormat']?['mainText']?['text'] as String?) ?? (p['text']?['text'] as String? ?? ''),
            address: (p['structuredFormat']?['secondaryText']?['text'] as String?) ?? '',
            location: near,
            needsLookup: true,
          ),
    ];
  }

  /// Name, address and coordinates of a suggestion. Ends the billing session.
  Future<Place> details(Place suggestion) async {
    final id = suggestion.id.substring(2);
    final res = await _http.get(
        Uri.parse('$_base/places/$id?sessionToken=$_session'),
        headers: _headers('id,displayName,formattedAddress,location'));
    _session = _newToken();
    if (res.statusCode != 200) throw PlacesException(res.statusCode, res.body);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final loc = j['location'] as Map<String, dynamic>;
    return Place(
      id: suggestion.id,
      name: (j['displayName']?['text'] as String?) ?? suggestion.name,
      address: _short((j['formattedAddress'] as String?) ?? suggestion.address),
      location: GeoPoint((loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble()),
    );
  }

  /// The nearest named place to [at] (to label the pickup point), or null.
  Future<Place?> nearest(GeoPoint at) async {
    final res = await _http.post(Uri.parse('$_base/places:searchNearby'),
        headers: _headers('places.id,places.displayName,places.formattedAddress'),
        body: jsonEncode({
          'maxResultCount': 1,
          'rankPreference': 'DISTANCE',
          'locationRestriction': {
            'circle': {'center': {'latitude': at.lat, 'longitude': at.lng}, 'radius': 120.0},
          },
        }));
    if (res.statusCode != 200) return null;
    final places = (jsonDecode(res.body)['places'] as List?) ?? const [];
    if (places.isEmpty) return null;
    final p = places.first as Map<String, dynamic>;
    return Place(
      id: 'current',
      name: (p['displayName']?['text'] as String?) ?? 'Current location',
      address: _short((p['formattedAddress'] as String?) ?? ''),
      location: at,
    );
  }

  /// "Bala Sokoto Wy, Jabi, Abuja 900108, Federal Capital Territory, Nigeria"
  /// → "Bala Sokoto Wy, Jabi, Abuja".
  static String _short(String a) {
    final parts = a.split(', ').where((p) => p != 'Nigeria' && !p.contains('Federal Capital Territory')).toList();
    return parts.map((p) => p.replaceAll(RegExp(r'\s\d{6}$'), '')).join(', ');
  }
}

class PlacesException implements Exception {
  PlacesException(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'PlacesException($status)';
}
