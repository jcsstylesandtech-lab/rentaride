/// Route paths for the passenger app. Use these constants instead of string
/// literals so routes can be renamed safely.
abstract final class AppRoutes {
  static const String welcome = '/';
  /// Choose Create Account, Log In or Google (after the welcome pages).
  static const String getStarted = '/get-started';
  static const String signUp = '/auth/sign-up';
  static const String logIn = '/auth/log-in';

  /// Expects an `OtpChallenge` as `extra`.
  static const String otp = '/auth/verify';
  static const String forgotPassword = '/auth/forgot-password';

  /// Expects the reset token (String) as `extra`.
  static const String resetPassword = '/auth/reset-password';
  static const String profileSetup = '/auth/profile-setup';
  static const String home = '/home';

  /// Optional `PlaceSearchArgs` as `extra`; pops with the chosen `Place`.
  static const String placeSearch = '/home/search';

  /// Development-only previews (not registered in production builds).
  static const String devLoadingStates = '/dev/loading-states';

  /// Routes only for signed-out users: signed-in users are sent home.
  static const signedOutOnly = {
    welcome,
    getStarted,
    signUp,
    logIn,
    forgotPassword,
  };

  /// Routes that need a signed-in user.
  static const signedInOnly = {home, profileSetup, placeSearch};
}
