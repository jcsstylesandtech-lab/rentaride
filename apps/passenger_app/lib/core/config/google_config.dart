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
    this.mapsApiKey,
    this.appIdentity = const {},
  });

  const GoogleConfig.none()
    : mapsConfigured = false,
      signInConfigured = false,
      mapsApiKey = null,
      appIdentity = const {};

  final bool mapsConfigured;
  final bool signInConfigured;

  /// The bundle-restricted Maps key, for Places search requests.
  final String? mapsApiKey;

  /// Headers that identify this app to Google web services, so a key
  /// restricted to the iOS bundle or Android package + certificate works.
  final Map<String, String> appIdentity;
}

const _channel = MethodChannel('ng.rentaride/config');

final googleConfigProvider = FutureProvider<GoogleConfig>((ref) async {
  try {
    final result = await _channel.invokeMapMethod<String, Object?>('googleConfig');
    final key = result?['mapsApiKey'] as String?;
    return GoogleConfig(
      mapsConfigured: result?['mapsConfigured'] == true,
      signInConfigured: result?['googleSignInConfigured'] == true,
      mapsApiKey: (key == null || key.isEmpty) ? null : key,
      appIdentity: defaultTargetPlatform == TargetPlatform.android
          ? {
              'X-Android-Package': (result?['androidPackage'] as String?) ?? '',
              'X-Android-Cert': (result?['androidCertSha1'] as String?) ?? '',
            }
          : const {'X-Ios-Bundle-Identifier': 'ng.rentaride.rentARidePassenger'},
    );
  } on MissingPluginException {
    // Platforms without the native channel yet (web, Android for now).
    return const GoogleConfig.none();
  } on PlatformException {
    return const GoogleConfig.none();
  }
});
