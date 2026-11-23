import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_models.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ride-hailing flows are designed for portrait use on phones.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Restore a saved Supabase session so returning riders skip the log-in.
  AuthUser? restored;
  if (AppConfig.hasBackend) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    restored = await SupabaseAuthRepository(Supabase.instance.client).currentUser();
  }

  runApp(
    ProviderScope(
      overrides: [initialUserProvider.overrideWithValue(restored)],
      child: const RentARideApp(),
    ),
  );
}
