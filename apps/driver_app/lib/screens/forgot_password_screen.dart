import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../core/format.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// Password reset: email → code from the email + new password. Ends signed
/// in with the new password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _codeAccepted = false; // a used code can't be checked twice
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await ref.read(repoProvider).sendPasswordResetCode(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _notice = 'We emailed a code to ${_email.text.trim()}. It may take a minute — check spam too.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    final repo = ref.read(repoProvider);
    final inProgress = ref.read(passwordResetInProgressProvider.notifier);
    inProgress.set(true);
    try {
      if (!_codeAccepted) {
        await repo.verifyPasswordResetCode(email: _email.text.trim(), code: _code.text.trim());
        _codeAccepted = true;
      }
      await repo.setNewPassword(_password.text);
      inProgress.set(false);
      if (!mounted) return;
      // Back to the gate, which now shows the signed-in driver.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      inProgress.set(false);
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DriverScaffold(
      child: ListView(
        children: [
          const SizedBox(height: RarSpacing.md),
          Row(children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded, color: RarColors.white),
            ),
            const RarWordmark(logoSize: 40, fontSize: 21, subtitle: 'Driver'),
          ]),
          const SizedBox(height: RarSpacing.xxl),
          Text('Reset your password', style: RarTypography.headlineLarge.copyWith(color: RarColors.white)),
          const SizedBox(height: RarSpacing.sm),
          Text(
            _codeSent
                ? 'Enter the code from the email and choose a new password.'
                : "Enter your account email. We'll send you a code to reset your password.",
            style: RarTypography.body.copyWith(color: RarColors.textOnDarkSecondary),
          ),
          const SizedBox(height: RarSpacing.xl),
          Form(
            key: _emailForm,
            child: RarTextField(
              key: const ValueKey('reset-email'),
              label: 'Email',
              controller: _email,
              enabled: !_codeSent,
              prefixIcon: Icons.mail_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                  ? null
                  : 'Enter a valid email',
              onFieldSubmitted: (_) => _sendCode(),
            ),
          ),
          if (_codeSent)
            Form(
              key: _resetForm,
              child: Column(children: [
                const SizedBox(height: RarSpacing.md),
                RarTextField(
                  key: const ValueKey('reset-code'),
                  label: 'Code from the email',
                  controller: _code,
                  enabled: !_codeAccepted,
                  prefixIcon: Icons.pin_rounded,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // Supabase codes are 6 digits by default (up to 10 if changed).
                  validator: (v) {
                    final n = (v ?? '').trim().length;
                    return n >= 6 && n <= 10 ? null : 'Enter the code from the email';
                  },
                ),
                const SizedBox(height: RarSpacing.md),
                RarTextField(
                  key: const ValueKey('reset-password'),
                  label: 'New password',
                  controller: _password,
                  prefixIcon: Icons.lock_rounded,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  helper: 'At least 8 characters with a letter and a number',
                  validator: (v) {
                    final s = v ?? '';
                    return s.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(s) && RegExp(r'\d').hasMatch(s)
                        ? null
                        : 'At least 8 characters with a letter and a number';
                  },
                ),
                const SizedBox(height: RarSpacing.md),
                RarTextField(
                  key: const ValueKey('reset-confirm'),
                  label: 'Confirm new password',
                  controller: _confirm,
                  prefixIcon: Icons.lock_rounded,
                  obscure: true,
                  validator: (v) => v == _password.text ? null : 'The passwords do not match',
                  onFieldSubmitted: (_) => _reset(),
                ),
              ]),
            ),
          if (_error != null) ...[
            const SizedBox(height: RarSpacing.md),
            Text(_error!, style: RarTypography.bodySmall.copyWith(color: RarColors.danger)),
          ],
          if (_notice != null) ...[
            const SizedBox(height: RarSpacing.md),
            Panel(child: Text(_notice!, style: RarTypography.bodySmall.copyWith(color: RarColors.cyan))),
          ],
          const SizedBox(height: RarSpacing.xl),
          RarButton.primary(
            key: ValueKey(_codeSent ? 'reset-submit' : 'reset-send'),
            label: _codeSent ? 'Save new password' : 'Send code',
            isLoading: _busy,
            onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
          ),
          if (_codeSent && !_codeAccepted) ...[
            const SizedBox(height: RarSpacing.md),
            TextButton(
              key: const ValueKey('reset-resend'),
              onPressed: _busy ? null : _sendCode,
              child: const Text('Send a new code', style: TextStyle(color: RarColors.textOnDarkSecondary)),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() { _codeSent = false; _notice = null; _error = null; }),
              child: const Text('Use a different email', style: TextStyle(color: RarColors.textOnDarkSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}
