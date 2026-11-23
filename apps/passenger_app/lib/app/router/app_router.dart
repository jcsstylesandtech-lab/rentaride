import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/log_in_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/password_reset_screens.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/dev/presentation/screens/loading_states_preview_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/place_search_screen.dart';
import '../../features/auth/presentation/screens/auth_entry_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import 'app_routes.dart';

/// App router. Redirects keep signed-out users away from signed-in screens
/// and vice versa, and re-run whenever the session changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AuthUser?>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: session,
    redirect: (context, state) {
      final signedIn = session.value != null;
      final path = state.matchedLocation;
      if (signedIn && AppRoutes.signedOutOnly.contains(path)) {
        return AppRoutes.home;
      }
      if (!signedIn && AppRoutes.signedInOnly.contains(path)) {
        return AppRoutes.welcome;
      }
      // These screens need data passed from the previous step; without it
      // (e.g. a restored route), start the step again.
      if (path == AppRoutes.otp && state.extra is! OtpChallenge) {
        return AppRoutes.logIn;
      }
      if (path == AppRoutes.resetPassword && state.extra is! String) {
        return AppRoutes.forgotPassword;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.getStarted,
        builder: (context, state) => const GetStartedScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => SignUpScreen(
          google: state.extra is GoogleProfile
              ? state.extra! as GoogleProfile
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.logIn,
        builder: (context, state) => LogInScreen(
          notice: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) =>
            OtpScreen(challenge: state.extra! as OtpChallenge),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) =>
            ResetPasswordScreen(resetToken: state.extra! as String),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.placeSearch,
        builder: (context, state) => PlaceSearchScreen(
          args: state.extra is PlaceSearchArgs
              ? state.extra! as PlaceSearchArgs
              : const PlaceSearchArgs(),
        ),
      ),
      if (!AppConfig.isProduction)
        GoRoute(
          path: AppRoutes.devLoadingStates,
          builder: (context, state) => const LoadingStatesPreviewScreen(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
