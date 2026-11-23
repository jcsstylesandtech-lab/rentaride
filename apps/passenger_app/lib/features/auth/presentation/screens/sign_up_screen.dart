import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validation/validators.dart';
import '../../domain/auth_models.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/google_sign_in_button.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.google});

  /// Set when arriving from "Continue with Google" with a Google account
  /// that has no Rent A Ride account yet: name and email are filled in and
  /// no password is needed.
  final GoogleProfile? google;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.google?.fullName);
  final _phone = TextEditingController();
  late final _email = TextEditingController(text: widget.google?.email);
  final _password = TextEditingController();
  bool _agreed = false;
  bool _showAgreeError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    setState(() => _showAgreeError = !_agreed);
    if (!valid || !_agreed) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .startSignUp(
            SignUpDetails(
              fullName: _name.text.trim(),
              phone: Validators.normaliseNigerianPhone(_phone.text)!,
              email: email.isEmpty ? null : email,
              password: _viaGoogle ? null : _password.text,
              viaGoogle: _viaGoogle,
            ),
          );
      if (mounted) context.push(AppRoutes.otp, extra: challenge);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
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

  bool get _viaGoogle => widget.google != null;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _viaGoogle ? 'Add your phone number' : 'Create your account',
      subtitle: _viaGoogle
          ? 'Drivers call and text riders, so we verify your number by SMS. '
                'You will log in with Google.'
          : 'It takes a minute. We verify your number by SMS.',
      footer: AuthSwitchPrompt(
        prompt: 'Already have an account?',
        action: 'Log in',
        onPressed: () => context.pushReplacement(AppRoutes.logIn),
      ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RarTextField(
                  label: 'Full name',
                  hint: 'Ada Okafor',
                  controller: _name,
                  prefixIcon: Icons.person_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                ),
                const SizedBox(height: RarSpacing.lg),
                RarTextField(
                  label: 'Phone number',
                  hint: '0803 123 4567',
                  controller: _phone,
                  prefixIcon: Icons.smartphone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: Validators.phone,
                ),
                const SizedBox(height: RarSpacing.lg),
                RarTextField(
                  enabled: !_viaGoogle,
                  label: _viaGoogle ? 'Google account' : 'Email (optional)',
                  hint: 'ada@example.com',
                  controller: _email,
                  prefixIcon: Icons.mail_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.optionalEmail,
                  helper: 'For receipts and logging in with email.',
                ),
                if (!_viaGoogle) const SizedBox(height: RarSpacing.lg),
                if (!_viaGoogle)
                  RarTextField(
                    label: 'Password',
                    controller: _password,
                    prefixIcon: Icons.lock_rounded,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.newPassword,
                    helper:
                        'At least 8 characters, with a letter and a number.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RarSpacing.md),
        CheckboxListTile(
          value: _agreed,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  _agreed = v ?? false;
                  if (_agreed) _showAgreeError = false;
                }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: RarColors.royal,
          title: Text(
            'I agree to the Rent A Ride Terms of Service and Privacy Policy.',
            style: RarTypography.bodySmall.copyWith(
              color: RarColors.textOnDarkSecondary,
              fontSize: 13,
            ),
          ),
          subtitle: _showAgreeError
              ? Text(
                  'Agree to the terms to create your account.',
                  style: RarTypography.bodySmall.copyWith(
                    color: RarColors.danger,
                  ),
                )
              : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.md),
          RarInlineMessage.error(
            _error!,
            action: _error!.contains('Log in')
                ? TextButton(
                    onPressed: () => context.pushReplacement(AppRoutes.logIn),
                    child: const Text('Go to log in'),
                  )
                : null,
          ),
        ],
        const SizedBox(height: RarSpacing.xl),
        RarButton.primary(
          label: 'Create Account',
          trailingIcon: Icons.arrow_forward_rounded,
          isLoading: _busy,
          onPressed: _submit,
        ),
        if (!_viaGoogle) ...[
          const SizedBox(height: RarSpacing.lg),
          const OrDivider(),
          const SizedBox(height: RarSpacing.lg),
          const GoogleSignInButton(),
        ],
      ],
    );
  }
}
