import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validation/validators.dart';
import '../../domain/auth_models.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Step 1 of password recovery: send a code to the account's phone.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  static String? _validate(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email or phone number.';
    if (value.contains('@')) return Validators.email(value);
    return Validators.phone(value);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(_account.text);
      if (mounted) context.pushReplacement(AppRoutes.otp, extra: challenge);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset your password',
      subtitle:
          "Enter your account's email or phone number. We'll text a code "
          'to the phone on your account.',
      children: [
        Form(
          key: _formKey,
          child: RarTextField(
            label: 'Email or phone number',
            hint: 'ada@example.com or 0803 123 4567',
            controller: _account,
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.lg),
          RarInlineMessage.error(_error!),
        ],
        const SizedBox(height: RarSpacing.xl),
        RarButton.primary(
          label: 'Send code',
          trailingIcon: Icons.arrow_forward_rounded,
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Step 3 of password recovery (after the code): choose a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.resetToken});

  final String resetToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resetPassword(widget.resetToken, _password.text);
      if (mounted) {
        context.go(
          AppRoutes.logIn,
          extra: 'Password updated. Log in with your new password.',
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Use at least 8 characters, with a letter and a number.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RarTextField(
                label: 'New password',
                controller: _password,
                prefixIcon: Icons.lock_rounded,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
              ),
              const SizedBox(height: RarSpacing.lg),
              RarTextField(
                label: 'Confirm new password',
                controller: _confirm,
                prefixIcon: Icons.lock_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v != _password.text ? 'The passwords do not match.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.lg),
          RarInlineMessage.error(_error!),
        ],
        const SizedBox(height: RarSpacing.xl),
        RarButton.primary(
          label: 'Update password',
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
