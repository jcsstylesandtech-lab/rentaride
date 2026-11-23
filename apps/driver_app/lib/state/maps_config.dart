import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a Google Maps key was built into the app (see ios/Flutter/Secrets.xcconfig).
final mapsConfiguredProvider = FutureProvider<bool>((ref) async {
  try {
    final r = await const MethodChannel('ng.rentaride/config').invokeMapMethod<String, Object?>('googleConfig');
    return r?['mapsConfigured'] == true;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
});
