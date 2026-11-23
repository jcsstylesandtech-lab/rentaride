import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../core/format.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.startWithSignUp = false});

  /// Open on "Create driver account" instead of sign in.
  final bool startWithSignUp;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.startWithSignUp;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    final repo = ref.read(repoProvider);
    try {
      if (_signUp) {
        final signedIn = await repo.signUp(name: _name.text.trim(), email: _email.text.trim(), password: _password.text);
        if (!signedIn && mounted) {
          setState(() {
            _signUp = false;
            _notice = 'Account created. Confirm your email from the link we sent, then sign in.';
          });
        }
      } else {
        await repo.signIn(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DriverScaffold(
      child: Form(
        key: _form,
        child: ListView(
          children: [
            const SizedBox(height: RarSpacing.md),
            Row(children: [
              if (Navigator.of(context).canPop())
                IconButton(onPressed: () => Navigator.of(context).pop(), tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded, color: RarColors.white)),
              const RarWordmark(logoSize: 40, fontSize: 21, subtitle: 'Driver'),
            ]),
            const SizedBox(height: RarSpacing.xxl),
            Text(_signUp ? 'Drive with Rent A Ride' : 'Welcome back, driver',
                style: RarTypography.headlineLarge.copyWith(color: RarColors.white)),
            const SizedBox(height: RarSpacing.sm),
            Text(
              _signUp
                  ? 'Earn on your own schedule. Create an account, add your car and documents, and our team will verify you.'
                  : 'Sign in to go online and start taking rides.',
              style: RarTypography.body.copyWith(color: RarColors.textOnDarkSecondary),
            ),
            const SizedBox(height: RarSpacing.xl),
            if (_signUp) ...[
              RarTextField(
                label: 'Full name (as on your licence)',
                controller: _name,
                prefixIcon: Icons.person_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().split(RegExp(r'\s+')).length < 2 ? 'Enter your first and last name' : null,
              ),
              const SizedBox(height: RarSpacing.md),
            ],
            RarTextField(
              label: 'Email',
              controller: _email,
              prefixIcon: Icons.mail_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
            ),
            const SizedBox(height: RarSpacing.md),
            RarTextField(
              label: 'Password',
              controller: _password,
              prefixIcon: Icons.lock_rounded,
              obscure: true,
              helper: _signUp ? 'At least 8 characters with a letter and a number' : null,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final s = v ?? '';
                if (!_signUp) return s.isEmpty ? 'Enter your password' : null;
                return s.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(s) && RegExp(r'\d').hasMatch(s)
                    ? null
                    : 'At least 8 characters with a letter and a number';
              },
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
              key: const ValueKey('auth-submit'),
              label: _signUp ? 'Create driver account' : 'Sign in',
              isLoading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: RarSpacing.md),
            TextButton(
              onPressed: _busy ? null : () => setState(() { _signUp = !_signUp; _error = null; }),
              child: Text(_signUp ? 'Already a driver? Sign in' : 'New driver? Create an account',
                  style: const TextStyle(color: RarColors.textOnDarkSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
