import 'auth_models.dart';

/// Authentication operations. The Phase 3 implementation calls the Rent A
/// Ride API (`/auth/*`) and stores tokens in secure storage; until then the
/// app uses `DemoAuthRepository`.
///
/// Every method throws [AuthFailure] with a user-facing message on failure.
abstract interface class AuthRepository {
  /// True when this is a local demo backend (shows test hints in the UI).
  bool get isDemo;

  /// False when the backend can't send SMS yet: sign-up and log-in then use
  /// email and password, with codes sent by email.
  bool get supportsPhoneCodes;

  Future<AuthUser?> currentUser();

  Future<AuthUser> logInWithEmail({
    required String email,
    required String password,
  });

  /// Logs in with a Google account. Returns null when no Rent A Ride
  /// account uses that Google email yet (the passenger then signs up,
  /// adding and verifying a phone number).
  ///
  /// The real backend must verify [GoogleProfile.idToken] with Google
  /// before trusting the email.
  Future<AuthUser?> logInWithGoogle(GoogleProfile profile);

  /// Sends a code for [purpose] to [phone] (E.164).
  Future<OtpChallenge> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  });

  /// Starts sign-up: validates the details and sends a code to the phone.
  Future<OtpChallenge> startSignUp(SignUpDetails details);

  /// Sends a password-reset code to an email or phone number.
  Future<OtpChallenge> requestPasswordReset(String emailOrPhone);

  Future<OtpChallenge> resendOtp(OtpChallenge challenge);

  Future<OtpResult> verifyOtp(OtpChallenge challenge, String code);

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  Future<AuthUser> updateProfile(
    AuthUser user, {
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
  });

  Future<void> signOut();
}
