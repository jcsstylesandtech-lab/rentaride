import 'package:flutter/foundation.dart';

/// A signed-in passenger.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String id;
  final String fullName;

  /// E.164, e.g. `+2348031234567`.
  final String phone;
  final String? email;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  bool get hasEmergencyContact => emergencyContactPhone != null;

  AuthUser copyWith({
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) => AuthUser(
    id: id,
    fullName: fullName,
    phone: phone,
    email: email ?? this.email,
    emergencyContactName: emergencyContactName ?? this.emergencyContactName,
    emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
  );
}

/// Why a one-time code was sent.
enum OtpPurpose { signUp, logIn, resetPassword }

/// A code sent by SMS, awaiting verification.
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.phone,
    required this.purpose,
    required this.resendAvailableAt,
  });

  final String id;

  /// E.164 phone number the code was sent to.
  final String phone;
  final OtpPurpose purpose;
  final DateTime resendAvailableAt;
}

/// Result of verifying a code.
sealed class OtpResult {
  const OtpResult();
}

/// Signed in (log in or completed sign-up).
class OtpSignedIn extends OtpResult {
  const OtpSignedIn(this.user, {required this.isNewAccount});
  final AuthUser user;
  final bool isNewAccount;
}

/// Verified for a password reset; [resetToken] authorises the new password.
class OtpPasswordResetAllowed extends OtpResult {
  const OtpPasswordResetAllowed(this.resetToken);
  final String resetToken;
}

/// Details collected on the Create Account form.
@immutable
class SignUpDetails {
  const SignUpDetails({
    required this.fullName,
    required this.phone,
    this.password,
    this.email,
    this.viaGoogle = false,
  });

  final String fullName;
  final String phone;

  /// Null for accounts created with Google (they log in with Google).
  final String? password;
  final String? email;
  final bool viaGoogle;
}

/// The Google account a passenger chose in the Google sign-in sheet.
@immutable
class GoogleProfile {
  const GoogleProfile({
    required this.email,
    required this.fullName,
    this.idToken,
  });

  final String email;
  final String fullName;

  /// Sent to the backend, which verifies it with Google (Phase 3).
  final String? idToken;
}

/// A failure the user can act on. [message] is written for the user.
class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final AuthFailureCode code;
  final String message;

  @override
  String toString() => 'AuthFailure($code): $message';
}

enum AuthFailureCode {
  invalidCredentials,
  accountNotFound,
  accountExists,
  invalidCode,
  codeExpired,
  tooManyAttempts,
  network,
  unknown,
}
