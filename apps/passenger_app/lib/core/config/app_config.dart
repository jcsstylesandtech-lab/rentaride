/// Build-time configuration, injected with `--dart-define` (or
/// `--dart-define-from-file=env/dev.json`).
///
/// Only **public, non-secret** values belong here. Anything shipped in a
/// mobile binary can be extracted, so payment secret keys, JWT secrets,
/// database credentials etc. live exclusively on the backend.
abstract final class AppConfig {
  /// `dev`, `staging` or `prod`.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// Base URL of the Rent A Ride REST API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// Base URL of the Socket.IO gateway.
  static const String realtimeUrl = String.fromEnvironment(
    'REALTIME_URL',
    defaultValue: 'http://localhost:3000',
  );

  static bool get isProduction => environment == 'prod';
}
