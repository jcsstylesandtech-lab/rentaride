/// Build-time configuration from `--dart-define-from-file=env/dev.json`.
///
/// Only public values belong here: the Supabase URL and its publishable
/// (browser-safe) key. Security comes from the database's row-level rules,
/// never from hiding these. The service-role key must never be in the app.
abstract final class AppConfig {
  static const environment = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
