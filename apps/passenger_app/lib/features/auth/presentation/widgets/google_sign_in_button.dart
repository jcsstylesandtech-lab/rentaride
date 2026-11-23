import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/google_config.dart';
import '../../domain/auth_models.dart';
import '../controllers/auth_controller.dart';

/// "Continue with Google". Signs in when a Rent A Ride account uses the
/// chosen Google email; otherwise opens sign-up with the name and email
/// filled in, so the passenger only adds and verifies a phone number.
///
/// Until a Google client ID is configured, tapping explains what is
/// missing instead of failing.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  static Future<void>? _initialized;
  bool _busy = false;

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _continue() async {
    final config = ref.read(googleConfigProvider).value;
    if (config == null || !config.signInConfigured) {
      _message(
        "Google sign-in isn't set up yet. Add your Google iOS client ID "
        'in ios/Flutter/Secrets.xcconfig (see docs/GOOGLE_SETUP.md).',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final google = GoogleSignIn.instance;
      // The client ID comes from Info.plist (GIDClientID) on iOS.
      await (_initialized ??= google.initialize());
      final account = await google.authenticate();
      final profile = GoogleProfile(
        email: account.email,
        fullName: account.displayName ?? '',
        idToken: account.authentication.idToken,
      );

      final signedIn = await ref
          .read(authControllerProvider.notifier)
          .logInWithGoogle(profile);
      if (!mounted) return;
      if (signedIn) {
        context.go(AppRoutes.home);
      } else {
        context.push(AppRoutes.signUp, extra: profile);
      }
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          break; // The passenger closed the Google sheet: nothing to report.
        case GoogleSignInExceptionCode.clientConfigurationError:
          _message(
            'Google sign-in is set up incorrectly. Check the client ID and '
            'URL scheme in ios/Flutter/Secrets.xcconfig.',
          );
        default:
          _message("Couldn't sign in with Google. Try again.");
      }
    } on AuthFailure catch (e) {
      if (mounted) _message(e.message);
    } catch (_) {
      if (mounted) {
        _message("Couldn't sign in with Google. Check your connection.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(googleConfigProvider).isLoading;

    return Semantics(
      button: true,
      label: 'Continue with Google',
      excludeSemantics: true,
      child: SizedBox(
        height: RarSpacing.buttonHeight,
        child: Material(
          color: RarColors.white,
          borderRadius: RarRadius.button,
          child: InkWell(
            key: const ValueKey('google-sign-in'),
            borderRadius: RarRadius.button,
            onTap: _busy || loading ? null : _continue,
            child: Center(
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 20,
                          child: CustomPaint(painter: _GoogleGPainter()),
                        ),
                        const SizedBox(width: RarSpacing.md),
                        Text(
                          'Continue with Google',
                          style: RarTypography.label.copyWith(
                            color: const Color(0xFF1F1F1F),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "or" with lines either side, between the main form and Google.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(color: RarColors.glassBorderDark, height: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RarSpacing.md),
          child: Text(
            'or',
            style: RarTypography.bodySmall.copyWith(
              color: RarColors.textOnDarkMuted,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Four-colour Google "G".
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double deg(double d) => d * math.pi / 180;

    canvas.drawArc(
      rect,
      deg(-40),
      deg(-95),
      false,
      arc(const Color(0xFFEA4335)),
    );
    canvas.drawArc(
      rect,
      deg(-135),
      deg(-90),
      false,
      arc(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      deg(135),
      deg(-85),
      false,
      arc(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      deg(50),
      deg(-50),
      false,
      arc(const Color(0xFF4285F4)),
    );
    // Crossbar.
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.5 - stroke / 2, s * 0.5, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}
