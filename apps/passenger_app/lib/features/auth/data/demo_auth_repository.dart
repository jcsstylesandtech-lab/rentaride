import 'dart:math';

import '../../../core/validation/validators.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// In-memory stand-in for the Rent A Ride auth API, used until the backend
/// exists (Phase 3). It enforces the same rules the API will: unique
/// phone/email, a 6-digit SMS code, attempt limits and a resend cooldown.
///
/// **Not for production.** No SMS is sent: every code is [demoCode].
/// Accounts live in memory and disappear when the app restarts.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({
    this.latency = const Duration(milliseconds: 700),
    this.resendCooldown = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _accounts[demoPhone] = _Account(
      const AuthUser(
        id: 'demo-user',
        fullName: 'Ada Okafor',
        phone: demoPhone,
        email: demoEmail,
      ),
      demoPassword,
    );
  }

  static const demoCode = '123456';
  static const demoPhone = '+2348031234567';
  static const demoEmail = 'demo@rentaride.ng';
  static const demoPassword = 'Demo1234';
  static const maxAttempts = 5;

  final Duration latency;
  final Duration resendCooldown;
  final DateTime Function() _now;

  final _accounts = <String, _Account>{}; // keyed by phone
  final _challenges = <String, _Challenge>{};
  final _resetTokens = <String, String>{}; // token → phone
  final _random = Random();
  AuthUser? _session;

  @override
  bool get isDemo => true;

  Future<void> _network() => Future<void>.delayed(latency);

  String _id() =>
      List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();

  _Account? _byEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final a in _accounts.values) {
      if (a.user.email?.toLowerCase() == e) return a;
    }
    return null;
  }

  @override
  Future<AuthUser?> currentUser() async => _session;

  @override
  Future<AuthUser> logInWithEmail({
    required String email,
    required String password,
  }) async {
    await _network();
    final account = _byEmail(email);
    if (account == null || account.password != password) {
      throw const AuthFailure(
        AuthFailureCode.invalidCredentials,
        'Email or password is incorrect. Check them and try again.',
      );
    }
    return _session = account.user;
  }

  @override
  Future<AuthUser?> logInWithGoogle(GoogleProfile profile) async {
    await _network();
    final account = _byEmail(profile.email);
    if (account == null) return null;
    return _session = account.user;
  }

  OtpChallenge _issue(
    String phone,
    OtpPurpose purpose, {
    SignUpDetails? signUp,
  }) {
    final challenge = OtpChallenge(
      id: _id(),
      phone: phone,
      purpose: purpose,
      resendAvailableAt: _now().add(resendCooldown),
    );
    _challenges[challenge.id] = _Challenge(challenge, signUp);
    return challenge;
  }

  @override
  Future<OtpChallenge> requestOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    await _network();
    if (purpose == OtpPurpose.logIn && !_accounts.containsKey(phone)) {
      throw const AuthFailure(
        AuthFailureCode.accountNotFound,
        'No account uses this number. Check it, or create an account.',
      );
    }
    return _issue(phone, purpose);
  }

  @override
  Future<OtpChallenge> startSignUp(SignUpDetails details) async {
    await _network();
    if (_accounts.containsKey(details.phone)) {
      throw const AuthFailure(
        AuthFailureCode.accountExists,
        'An account already uses this number. Log in instead.',
      );
    }
    if (details.email != null && _byEmail(details.email!) != null) {
      throw const AuthFailure(
        AuthFailureCode.accountExists,
        'An account already uses this email. Log in instead.',
      );
    }
    return _issue(details.phone, OtpPurpose.signUp, signUp: details);
  }

  @override
  Future<OtpChallenge> requestPasswordReset(String emailOrPhone) async {
    await _network();
    final phone = Validators.normaliseNigerianPhone(emailOrPhone);
    final account = phone != null ? _accounts[phone] : _byEmail(emailOrPhone);
    if (account == null) {
      throw const AuthFailure(
        AuthFailureCode.accountNotFound,
        'We could not find an account with that email or number.',
      );
    }
    return _issue(account.user.phone, OtpPurpose.resetPassword);
  }

  @override
  Future<OtpChallenge> resendOtp(OtpChallenge challenge) async {
    await _network();
    final stored = _challenges.remove(challenge.id);
    if (stored == null) {
      throw const AuthFailure(
        AuthFailureCode.codeExpired,
        'This code has expired. Go back and start again.',
      );
    }
    return _issue(challenge.phone, challenge.purpose, signUp: stored.signUp);
  }

  @override
  Future<OtpResult> verifyOtp(OtpChallenge challenge, String code) async {
    await _network();
    final stored = _challenges[challenge.id];
    if (stored == null) {
      throw const AuthFailure(
        AuthFailureCode.codeExpired,
        'This code has expired. Request a new one.',
      );
    }
    if (code != demoCode) {
      stored.attempts++;
      if (stored.attempts >= maxAttempts) {
        _challenges.remove(challenge.id);
        throw const AuthFailure(
          AuthFailureCode.tooManyAttempts,
          'Too many incorrect codes. Request a new code to try again.',
        );
      }
      throw AuthFailure(
        AuthFailureCode.invalidCode,
        'That code is incorrect. '
        '${maxAttempts - stored.attempts} attempts left.',
      );
    }
    _challenges.remove(challenge.id);

    switch (challenge.purpose) {
      case OtpPurpose.signUp:
        final d = stored.signUp!;
        final user = AuthUser(
          id: _id(),
          fullName: d.fullName.trim(),
          phone: d.phone,
          email: d.email,
        );
        _accounts[d.phone] = _Account(user, d.password);
        _session = user;
        return OtpSignedIn(user, isNewAccount: true);
      case OtpPurpose.logIn:
        _session = _accounts[challenge.phone]!.user;
        return OtpSignedIn(_session!, isNewAccount: false);
      case OtpPurpose.resetPassword:
        final token = _id();
        _resetTokens[token] = challenge.phone;
        return OtpPasswordResetAllowed(token);
    }
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _network();
    final phone = _resetTokens.remove(resetToken);
    if (phone == null) {
      throw const AuthFailure(
        AuthFailureCode.codeExpired,
        'This reset link has expired. Start the reset again.',
      );
    }
    _accounts[phone]!.password = newPassword;
  }

  @override
  Future<AuthUser> updateProfile(
    AuthUser user, {
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    await _network();
    if (email != null) {
      final other = _byEmail(email);
      if (other != null && other.user.id != user.id) {
        throw const AuthFailure(
          AuthFailureCode.accountExists,
          'Another account already uses this email.',
        );
      }
    }
    final updated = user.copyWith(
      email: email,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );
    _accounts[user.phone]!.user = updated;
    return _session = updated;
  }

  @override
  Future<void> signOut() async {
    _session = null;
  }
}

class _Account {
  _Account(this.user, this.password);
  AuthUser user;

  /// Null for Google-only accounts.
  String? password;
}

class _Challenge {
  _Challenge(this.challenge, this.signUp);
  final OtpChallenge challenge;
  final SignUpDetails? signUp;
  int attempts = 0;
}
