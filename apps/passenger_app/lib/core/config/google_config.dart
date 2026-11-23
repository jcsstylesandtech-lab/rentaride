import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which Google features have keys configured on this build.
///
/// Keys live in native config (iOS: `ios/Flutter/Secrets.xcconfig`), so the
/// app asks the platform rather than embedding them in Dart code.
@immutable
class GoogleConfig {
  const GoogleConfig({
    required this.mapsConfigured,
    required this.signInConfigured,
  });

  const GoogleConfig.none() : mapsConfigured = false, signInConfigured = false;

  final bool mapsConfigured;
  final bool signInConfigured;
}

const _channel = MethodChannel('ng.rentaride/config');

final googleConfigProvider = FutureProvider<GoogleConfig>((ref) async {
  try {
    final result = await _channel.invokeMapMethod<String, bool>('googleConfig');
    return GoogleConfig(
      mapsConfigured: result?['mapsConfigured'] ?? false,
      signInConfigured: result?['googleSignInConfigured'] ?? false,
    );
  } on MissingPluginException {
    // Platforms without the native channel yet (web, Android for now).
    return const GoogleConfig.none();
  } on PlatformException {
    return const GoogleConfig.none();
  }
});
