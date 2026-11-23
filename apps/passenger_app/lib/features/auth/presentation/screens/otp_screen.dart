import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validation/validators.dart';
import '../../data/demo_auth_repository.dart';
import '../../domain/auth_models.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Verifies the 6-digit SMS code for sign-up, log-in or password reset.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.challenge});

  final OtpChallenge challenge;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  late OtpChallenge _challenge = widget.challenge;
  Timer? _ticker;
  int _secondsLeft = 0;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  int _remaining() {
    final left = _challenge.resendAvailableAt
        .difference(DateTime.now())
        .inSeconds;
    return left < 0 ? 0 : left;
  }

  void _startCountdown() {
    _ticker?.cancel();
    _secondsLeft = _remaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _remaining();
      setState(() => _secondsLeft = left);
      if (left == 0) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify([String? code]) async {
    final value = code ?? _code.text;
    if (value.length != 6) {
      setState(() => _error = 'Enter all 6 digits of the code.');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .verifyCode(_challenge, value);
      if (!mounted) return;
      switch (result) {
        case OtpSignedIn(isNewAccount: true):
          context.go(AppRoutes.profileSetup);
        case OtpSignedIn():
          context.go(AppRoutes.home);
        case OtpPasswordResetAllowed(:final resetToken):
          context.pushReplacement(AppRoutes.resetPassword, extra: resetToken);
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _code.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Something went wrong. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final next = await ref
          .read(authControllerProvider.notifier)
          .resendCode(_challenge);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _challenge = next;
        _info = 'We sent a new code.';
      });
      _startCountdown();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(authRepositoryProvider).isDemo;
    final masked = Validators.maskNigerianPhone(_challenge.phone);

    return AuthScaffold(
      title: 'Enter the code',
      subtitle: 'We sent a 6-digit code by SMS to $masked.',
      children: [
        RarOtpField(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          onCompleted: _verify,
          // Typing a new code hides the old error; the field being cleared
          // after a wrong code must not hide it.
          onChanged: (value) {
            if (value.isNotEmpty && _error != null) {
              setState(() => _error = null);
            }
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.lg),
          RarInlineMessage.error(_error!),
        ],
        if (_info != null) ...[
          const SizedBox(height: RarSpacing.lg),
          RarInlineMessage.success(_info!),
        ],
        const SizedBox(height: RarSpacing.xl),
        RarButton.primary(
          key: const ValueKey('otp-verify'),
          label: 'Verify',
          isLoading: _busy,
          onPressed: () => _verify(),
        ),
        const SizedBox(height: RarSpacing.md),
        Center(
          child: _secondsLeft > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: RarTypography.body.copyWith(
                      color: RarColors.textOnDarkMuted,
                    ),
                  ),
                )
              : TextButton.icon(
                  key: const ValueKey('otp-resend'),
                  onPressed: _resending || _busy ? null : _resend,
                  icon: _resending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Resend code'),
                ),
        ),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => context.pop(),
            child: const Text('Change number'),
          ),
        ),
        if (isDemo) ...[
          const SizedBox(height: RarSpacing.lg),
          const DemoModeHint(
            lines: ['Enter the code ${DemoAuthRepository.demoCode}.'],
          ),
        ],
      ],
    );
  }
}
