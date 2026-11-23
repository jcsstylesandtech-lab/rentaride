import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Accounts on Supabase Auth. Until an SMS provider is connected, passengers
/// sign up and log in with email + password; 6-digit codes (account
/// confirmation, password reset) arrive by email.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._db);
  final SupabaseClient _db;

  GoTrueClient get _auth => _db.auth;

  @override
  bool get isDemo => false;

  @override
  bool get supportsPhoneCodes => false;

  static const _cooldown = Duration(seconds: 60);

  // ---------- helpers ----------
  Never _fail(Object e) {
    if (e is AuthFailure) throw e;
    final msg = switch (e) {
      AuthException(:final message) => message,
      PostgrestException(:final message) => message,
      _ => e.toString(),
    };
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials, 'Email or password is incorrect. Check them and try again.');
    }
    if (lower.contains('email not confirmed')) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials, 'Confirm your email first — check your inbox for the code or link we sent.');
    }
    if (lower.contains('already registered') || lower.contains('already exists')) {
      throw const AuthFailure(AuthFailureCode.accountExists, 'An account already uses this email. Log in instead.');
    }
    if (lower.contains('expired') || lower.contains('invalid') && lower.contains('token')) {
      throw const AuthFailure(AuthFailureCode.invalidCode, 'That code is wrong or has expired. Check it or send a new one.');
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      throw const AuthFailure(AuthFailureCode.tooManyAttempts, 'Too many attempts. Wait a minute and try again.');
    }
    if (lower.contains('socket') || lower.contains('host lookup') || lower.contains('network')) {
      throw const AuthFailure(AuthFailureCode.network, 'No internet connection. Check your network and try again.');
    }
    throw AuthFailure(AuthFailureCode.unknown, msg);
  }

  Future<AuthUser> _loadUser() async {
    final u = _auth.currentUser;
    if (u == null) throw const AuthFailure(AuthFailureCode.accountNotFound, 'Not signed in.');
    final profile = await _db.from('profiles').select('full_name, phone, email, role').eq('id', u.id).maybeSingle();
    final contact = await _db.from('emergency_contacts').select('name, phone').eq('user_id', u.id)
        .order('created_at').limit(1).maybeSingle();
    if (profile != null && profile['role'] != 'passenger') {
      await _auth.signOut();
      throw const AuthFailure(AuthFailureCode.invalidCredentials,
          'This is a driver or staff account. Use the Rent A Ride Driver app or the admin dashboard.');
    }
    return AuthUser(
      id: u.id,
      fullName: (profile?['full_name'] as String?)?.trim().isNotEmpty == true
          ? profile!['full_name'] as String
          : (u.userMetadata?['full_name'] as String?) ?? 'Rider',
      phone: (profile?['phone'] as String?) ?? (u.userMetadata?['phone'] as String?) ?? '',
      email: u.email ?? profile?['email'] as String?,
      emergencyContactName: contact?['name'] as String?,
      emergencyContactPhone: contact?['phone'] as String?,
    );
  }

  OtpChallenge _emailChallenge(String email, OtpPurpose purpose) => OtpChallenge(
        id: '${purpose.name}:$email',
        phone: email,
        purpose: purpose,
        resendAvailableAt: DateTime.now().add(_cooldown),
        viaEmail: true,
      );

  // ---------- AuthRepository ----------
  @override
  Future<AuthUser?> currentUser() async {
    if (_auth.currentSession == null) return null;
    try {
      return await _loadUser();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthUser> logInWithEmail({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      return await _loadUser();
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<AuthUser?> logInWithGoogle(GoogleProfile profile) async {
    final token = profile.idToken;
    if (token == null) {
      throw const AuthFailure(AuthFailureCode.unknown, 'Google did not return a sign-in token. Try again.');
    }
    try {
      // Supabase verifies the Google ID token itself.
      await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: token);
      return await _loadUser();
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('provider') || e.message.toLowerCase().contains('not enabled')) {
        throw const AuthFailure(AuthFailureCode.unknown,
            "Google sign-in isn't switched on for this server yet. Use email for now.");
      }
      _fail(e);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<OtpChallenge> requestOtp({required String phone, required OtpPurpose purpose}) async {
    throw const AuthFailure(AuthFailureCode.unknown, 'Text-message codes are coming soon. Log in with your email for now.');
  }

  @override
  Future<OtpChallenge> startSignUp(SignUpDetails details) async {
    final email = details.email?.trim();
    final password = details.password;
    if (email == null || email.isEmpty || password == null) {
      throw const AuthFailure(AuthFailureCode.unknown, 'Add an email and password to create your account.');
    }
    try {
      final res = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': details.fullName, 'phone': details.phone, 'role': 'passenger'},
      );
      // Supabase hides "already registered" by returning a user with no identities.
      if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
        throw const AuthFailure(AuthFailureCode.accountExists, 'An account already uses this email. Log in instead.');
      }
      if (res.session != null) {
        return OtpChallenge(id: 'signed-in', phone: email, purpose: OtpPurpose.signUp,
            resendAvailableAt: DateTime.now(), viaEmail: true, alreadyVerified: true);
      }
      return _emailChallenge(email, OtpPurpose.signUp);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<OtpChallenge> requestPasswordReset(String emailOrPhone) async {
    final value = emailOrPhone.trim();
    if (!value.contains('@')) {
      throw const AuthFailure(AuthFailureCode.unknown, 'Enter the email on your account — text-message codes are coming soon.');
    }
    try {
      await _auth.resetPasswordForEmail(value);
      return _emailChallenge(value, OtpPurpose.resetPassword);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<OtpChallenge> resendOtp(OtpChallenge challenge) async {
    try {
      if (challenge.purpose == OtpPurpose.signUp) {
        await _auth.resend(type: OtpType.signup, email: challenge.phone);
      } else {
        await _auth.resetPasswordForEmail(challenge.phone);
      }
      return _emailChallenge(challenge.phone, challenge.purpose);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<OtpResult> verifyOtp(OtpChallenge challenge, String code) async {
    try {
      final recovery = challenge.purpose == OtpPurpose.resetPassword;
      await _auth.verifyOTP(email: challenge.phone, token: code.trim(),
          type: recovery ? OtpType.recovery : OtpType.signup);
      if (recovery) return const OtpPasswordResetAllowed('session');
      return OtpSignedIn(await _loadUser(), isNewAccount: true);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> resetPassword({required String resetToken, required String newPassword}) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      await _auth.signOut(); // log in again with the new password
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<AuthUser> updateProfile(AuthUser user,
      {String? email, String? emergencyContactName, String? emergencyContactPhone}) async {
    try {
      if (email != null && email.trim() != user.email) {
        // Supabase emails a confirmation link to the new address first.
        await _auth.updateUser(UserAttributes(email: email.trim()));
      }
      if (emergencyContactPhone != null) {
        final existing = await _db.from('emergency_contacts').select('id').eq('user_id', user.id).limit(1).maybeSingle();
        final row = {'user_id': user.id, 'name': emergencyContactName ?? 'Emergency contact', 'phone': emergencyContactPhone};
        if (existing == null) {
          await _db.from('emergency_contacts').insert(row);
        } else {
          await _db.from('emergency_contacts').update(row).eq('id', existing['id'] as String);
        }
      }
      return user.copyWith(
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
      );
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
