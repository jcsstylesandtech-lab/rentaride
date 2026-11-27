import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../data/demo_auth_repository.dart';
import '../../data/supabase_auth_repository.dart';
import '../../domain/auth_models.dart';
import '../../domain/auth_repository.dart';

/// The auth backend: Supabase when the app is built with its settings
/// (`--dart-define-from-file=env/dev.json`), otherwise the in-memory demo.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppConfig.hasBackend
      ? SupabaseAuthRepository(Supabase.instance.client)
      : DemoAuthRepository(),
);

/// The passenger restored from a saved session at launch (set in main).
final initialUserProvider = Provider<AuthUser?>((ref) => null);

/// The signed-in passenger, or null when signed out.
final authControllerProvider = NotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);

/// Screens call these methods; each throws [AuthFailure] with a message
/// to show the user.
class AuthController extends Notifier<AuthUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Developer shortcut: `--dart-define=DEMO_SIGNED_IN=true` starts signed
  /// in as the demo passenger. Ignored in production builds.
  static const _demoSignedIn = bool.fromEnvironment('DEMO_SIGNED_IN');

  @override
  AuthUser? build() {
    final restored = ref.read(initialUserProvider);
    if (restored != null) return restored;
    if (_demoSignedIn && !AppConfig.isProduction && !AppConfig.hasBackend) {
      return const AuthUser(
        id: 'demo-user',
        fullName: 'Ada Okafor',
        phone: DemoAuthRepository.demoPhone,
        email: DemoAuthRepository.demoEmail,
      );
    }
    return null;
  }

  bool get isDemo => _repo.isDemo;

  /// Reloads the signed-in passenger's details (pull-to-refresh).
  Future<void> refresh() async {
    if (state == null) return;
    final user = await _repo.currentUser();
    if (user != null) state = user;
  }

  Future<void> logInWithEmail(String email, String password) async {
    state = await _repo.logInWithEmail(email: email.trim(), password: password);
  }

  /// Signs in if an account uses this Google email; returns false when the
  /// passenger still needs to sign up.
  Future<bool> logInWithGoogle(GoogleProfile profile) async {
    final user = await _repo.logInWithGoogle(profile);
    if (user == null) return false;
    state = user;
    return true;
  }

  Future<OtpChallenge> requestLogInCode(String phone) =>
      _repo.requestOtp(phone: phone, purpose: OtpPurpose.logIn);

  Future<OtpChallenge> startSignUp(SignUpDetails details) async {
    final challenge = await _repo.startSignUp(details);
    if (challenge.alreadyVerified) state = await _repo.currentUser();
    return challenge;
  }

  Future<OtpChallenge> requestPasswordReset(String emailOrPhone) =>
      _repo.requestPasswordReset(emailOrPhone.trim());

  Future<OtpChallenge> resendCode(OtpChallenge challenge) =>
      _repo.resendOtp(challenge);

  Future<OtpResult> verifyCode(OtpChallenge challenge, String code) async {
    final result = await _repo.verifyOtp(challenge, code);
    if (result is OtpSignedIn) state = result.user;
    return result;
  }

  Future<void> resetPassword(String token, String newPassword) =>
      _repo.resetPassword(resetToken: token, newPassword: newPassword);

  Future<void> updateProfile({
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final user = state;
    if (user == null) return;
    state = await _repo.updateProfile(
      user,
      email: email,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = null;
  }
}
