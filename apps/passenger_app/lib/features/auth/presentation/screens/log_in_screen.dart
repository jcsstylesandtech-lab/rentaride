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
import '../widgets/google_sign_in_button.dart';

enum _Method { phone, email }

class LogInScreen extends ConsumerStatefulWidget {
  const LogInScreen({super.key, this.notice});

  /// Success message to show on arrival, e.g. after a password reset.
  final String? notice;

  @override
  ConsumerState<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends ConsumerState<LogInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Method _method = _Method.phone;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_method == _Method.phone &&
          ref.read(authRepositoryProvider).supportsPhoneCodes) {
        final phone = Validators.normaliseNigerianPhone(_phone.text)!;
        final challenge = await auth.requestLogInCode(phone);
        if (mounted) context.push(AppRoutes.otp, extra: challenge);
      } else {
        await auth.logInWithEmail(_email.text, _password.text);
        if (mounted) context.go(AppRoutes.home);
      }
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

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(authRepositoryProvider).isDemo;
    // Without SMS codes the backend logs in with email only.
    final phoneCodes = ref.watch(authRepositoryProvider).supportsPhoneCodes;
    final method = phoneCodes ? _method : _Method.email;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to book rides, track drivers and pay securely.',
      footer: AuthSwitchPrompt(
        prompt: 'New to Rent A Ride?',
        action: 'Create account',
        onPressed: () => context.pushReplacement(AppRoutes.signUp),
      ),
      children: [
        if (widget.notice != null) ...[
          RarInlineMessage.success(widget.notice!),
          const SizedBox(height: RarSpacing.lg),
        ],
        if (phoneCodes) SegmentedButton<_Method>(
          segments: const [
            ButtonSegment(
              value: _Method.phone,
              label: Text('Phone'),
              icon: Icon(Icons.smartphone_rounded),
            ),
            ButtonSegment(
              value: _Method.email,
              label: Text('Email'),
              icon: Icon(Icons.mail_rounded),
            ),
          ],
          selected: {_method},
          showSelectedIcon: false,
          onSelectionChanged: _busy
              ? null
              : (s) => setState(() {
                  _method = s.first;
                  _error = null;
                }),
        ),
        const SizedBox(height: RarSpacing.xl),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: method == _Method.phone
                  ? [
                      RarTextField(
                        key: const ValueKey('login-phone'),
                        label: 'Phone number',
                        hint: '0803 123 4567',
                        controller: _phone,
                        prefixIcon: Icons.smartphone_rounded,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        validator: Validators.phone,
                        onFieldSubmitted: (_) => _submit(),
                        helper: "We'll text you a 6-digit code.",
                      ),
                    ]
                  : [
                      RarTextField(
                        key: const ValueKey('login-email'),
                        label: 'Email',
                        hint: 'ada@example.com',
                        controller: _email,
                        prefixIcon: Icons.mail_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                      ),
                      const SizedBox(height: RarSpacing.lg),
                      RarTextField(
                        key: const ValueKey('login-password'),
                        label: 'Password',
                        controller: _password,
                        prefixIcon: Icons.lock_rounded,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: Validators.requiredPassword,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.lg),
          RarInlineMessage.error(_error!),
        ],
        const SizedBox(height: RarSpacing.xl),
        RarButton.primary(
          key: const ValueKey('login-submit'),
          label: method == _Method.phone ? 'Send code' : 'Log In',
          trailingIcon: Icons.arrow_forward_rounded,
          isLoading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: RarSpacing.lg),
        const OrDivider(),
        const SizedBox(height: RarSpacing.lg),
        const GoogleSignInButton(),
        if (isDemo) ...[
          const SizedBox(height: RarSpacing.xl),
          const DemoModeHint(
            lines: [
              'Phone: 0803 123 4567',
              'Email: ${DemoAuthRepository.demoEmail}',
              'Password: ${DemoAuthRepository.demoPassword}',
              'SMS code: ${DemoAuthRepository.demoCode}',
            ],
          ),
        ],
      ],
    );
  }
}
