import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validation/validators.dart';
import '../../domain/auth_models.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Shown once after sign-up: add an emergency contact (used by SOS and
/// trip sharing) and, if missing, an email for receipts. Both optional.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _contactName.dispose();
    _contactPhone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _contactPhoneValidator(String? v) {
    final hasName = _contactName.text.trim().isNotEmpty;
    if ((v == null || v.trim().isEmpty) && !hasName) return null;
    return Validators.phone(v);
  }

  String? _contactNameValidator(String? v) {
    final hasPhone = _contactPhone.text.trim().isNotEmpty;
    if ((v == null || v.trim().isEmpty) && hasPhone) {
      return "Enter your contact's name.";
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final name = _contactName.text.trim();
    final phone = _contactPhone.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty && email.isEmpty) {
      context.go(AppRoutes.home);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            email: email.isEmpty ? null : email,
            emergencyContactName: name.isEmpty ? null : name,
            emergencyContactPhone: phone.isEmpty
                ? null
                : Validators.normaliseNigerianPhone(phone),
          );
      if (mounted) context.go(AppRoutes.home);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final needsEmail = user?.email == null;

    return AuthScaffold(
      title: 'Welcome, ${user?.firstName ?? 'rider'}!',
      subtitle:
          'Add someone we can alert if you press SOS on a trip. '
          'You can change this later in Safety settings.',
      showBack: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassContainer(
                child: Row(
                  children: [
                    const IconTile(icon: Icons.sos_rounded, size: 40),
                    const SizedBox(width: RarSpacing.md),
                    Expanded(
                      child: Text(
                        'Your emergency contact gets your live location and '
                        'driver details only when you press SOS.',
                        style: RarTypography.bodySmall.copyWith(
                          color: RarColors.textOnDarkSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RarSpacing.xl),
              RarTextField(
                label: 'Emergency contact name',
                hint: 'Chidi Okafor',
                controller: _contactName,
                prefixIcon: Icons.person_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: _contactNameValidator,
              ),
              const SizedBox(height: RarSpacing.lg),
              RarTextField(
                label: 'Emergency contact phone',
                hint: '0805 555 0123',
                controller: _contactPhone,
                prefixIcon: Icons.smartphone_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: needsEmail
                    ? TextInputAction.next
                    : TextInputAction.done,
                validator: _contactPhoneValidator,
              ),
              if (needsEmail) ...[
                const SizedBox(height: RarSpacing.lg),
                RarTextField(
                  label: 'Email for receipts (optional)',
                  hint: 'ada@example.com',
                  controller: _email,
                  prefixIcon: Icons.mail_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: Validators.optionalEmail,
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.lg),
          RarInlineMessage.error(_error!),
        ],
        const SizedBox(height: RarSpacing.xl),
        RarButton.primary(
          label: 'Save and continue',
          isLoading: _busy,
          onPressed: _save,
        ),
        const SizedBox(height: RarSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => context.go(AppRoutes.home),
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }
}
