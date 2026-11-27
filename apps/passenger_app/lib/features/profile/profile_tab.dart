import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../app/router/app_routes.dart';
import '../../core/validation/validators.dart';
import '../app_control/app_control.dart';
import '../auth/domain/auth_models.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import '../home/presentation/controllers/home_providers.dart';
import '../home/presentation/screens/place_search_screen.dart';
import '../home/presentation/widgets/account_tabs.dart';
import '../map/map_data.dart';
import '../messages/messages.dart';
import '../messages/messages_tab.dart';
import 'profile_photo.dart';

/// Account, safety, saved places, payments, preferences, help, sign out.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  // Preferences: kept for this session until the account API stores them.
  bool _shareTrips = false;
  bool _rideAlerts = true;
  bool _promotions = false;
  bool _signingOut = false;
  bool _photoBusy = false;

  Future<void> _changePhoto() async {
    setState(() => _photoBusy = true);
    final message = await changeProfilePhoto(context, ref);
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (message != null) _toast(message);
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editEmail(AuthUser user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(
        title: user.email == null ? 'Add email' : 'Change email',
        fields: [
          _FieldSpec(
            label: 'Email',
            initial: user.email ?? '',
            icon: Icons.mail_rounded,
            keyboard: TextInputType.emailAddress,
            validator: Validators.email,
          ),
        ],
        onSave: (values) => ref
            .read(authControllerProvider.notifier)
            .updateProfile(email: values[0].trim()),
      ),
    );
    if (saved == true) _toast('Email saved.');
  }

  Future<void> _editEmergencyContact(AuthUser user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(
        title: 'Emergency contact',
        note:
            'We share your live location and driver details with them '
            'only when you press SOS.',
        fields: [
          _FieldSpec(
            label: 'Name',
            initial: user.emergencyContactName ?? '',
            icon: Icons.person_rounded,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "Enter your contact's name."
                : null,
          ),
          _FieldSpec(
            label: 'Phone number',
            initial: user.emergencyContactPhone == null
                ? ''
                : Validators.formatNigerianPhone(user.emergencyContactPhone!),
            icon: Icons.smartphone_rounded,
            keyboard: TextInputType.phone,
            validator: Validators.phone,
          ),
        ],
        onSave: (values) => ref
            .read(authControllerProvider.notifier)
            .updateProfile(
              emergencyContactName: values[0].trim(),
              emergencyContactPhone: Validators.normaliseNigerianPhone(
                values[1],
              ),
            ),
      ),
    );
    if (saved == true) _toast('Emergency contact saved.');
  }

  Future<void> _setPlace(SavedPlaceSlot slot) async {
    final place = await context.push<Place>(
      AppRoutes.placeSearch,
      extra: PlaceSearchArgs(saveAs: slot),
    );
    if (place == null || !mounted) return;
    await savePlace(ref, slot, place);
    if (mounted) {
      _toast(
        '${slot == SavedPlaceSlot.home ? 'Home' : 'Work'} set to '
        '${place.name}.',
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign out?', style: RarTypography.headline),
              const SizedBox(height: RarSpacing.sm),
              Text(
                "You'll need your phone, email or Google account to log in "
                'again.',
                style: RarTypography.body.copyWith(
                  color: RarColors.textSecondary,
                ),
              ),
              const SizedBox(height: RarSpacing.xl),
              RarButton.primary(
                label: 'Sign out',
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: RarSpacing.md),
              RarButton.outline(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    if (user == null) return const SizedBox.shrink();
    final saved = ref.watch(savedPlacesProvider).value ?? const {};
    final photo = ref.watch(profilePhotoProvider);

    return TabPage(
      title: 'Profile',
      onRefresh: () async {
        await ref.read(authControllerProvider.notifier).refresh();
        await Future.wait([
          ref.refresh(profilePhotoProvider.future),
          ref.refresh(savedPlacesProvider.future),
        ]);
      },
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(RarSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [RarColors.navy700, RarColors.navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: RarRadius.card,
            boxShadow: RarShadows.medium,
          ),
          child: Row(
            children: [
              RarAvatar(
                key: const ValueKey('profile-photo'),
                name: user.fullName,
                imageUrl: photo.value,
                busy: _photoBusy,
                onEdit: _changePhoto,
              ),
              const SizedBox(width: RarSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: RarTypography.title.copyWith(
                        color: RarColors.white,
                      ),
                    ),
                    Text(
                      Validators.formatNigerianPhone(user.phone),
                      style: RarTypography.bodySmall.copyWith(
                        color: RarColors.textOnDarkSecondary,
                      ),
                    ),
                    const SizedBox(height: RarSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: const [
                        _Chip(
                          icon: Icons.verified_rounded,
                          label: 'Phone verified',
                        ),
                        _Chip(icon: Icons.star_rounded, label: 'New rider'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        _Section(
          title: 'Account',
          children: [
            _Row(
              icon: Icons.mail_rounded,
              title: 'Email',
              value: user.email ?? 'Add an email for receipts',
              onTap: () => _editEmail(user),
            ),
            _Row(
              icon: Icons.smartphone_rounded,
              title: 'Phone',
              value:
                  '${Validators.formatNigerianPhone(user.phone)} · '
                  'message Support to change it',
            ),
          ],
        ),

        _Section(
          title: 'Safety',
          children: [
            _Row(
              icon: Icons.sos_rounded,
              title: 'Emergency contact',
              value: user.hasEmergencyContact
                  ? '${user.emergencyContactName} · '
                        '${Validators.formatNigerianPhone(user.emergencyContactPhone!)}'
                  : 'Not added: add someone to alert if you press SOS',
              highlight: !user.hasEmergencyContact,
              onTap: () => _editEmergencyContact(user),
            ),
            _SwitchRow(
              icon: Icons.share_location_rounded,
              title: 'Share every trip automatically',
              value: 'Your emergency contact gets a live trip link',
              on: _shareTrips,
              enabled: user.hasEmergencyContact,
              onChanged: (v) => setState(() => _shareTrips = v),
            ),
          ],
        ),

        _Section(
          title: 'Saved places',
          children: [
            _Row(
              icon: Icons.home_rounded,
              title: 'Home',
              value: saved[SavedPlaceSlot.home]?.name ?? 'Add home',
              onTap: () => _setPlace(SavedPlaceSlot.home),
            ),
            _Row(
              icon: Icons.work_rounded,
              title: 'Work',
              value: saved[SavedPlaceSlot.work]?.name ?? 'Add work',
              onTap: () => _setPlace(SavedPlaceSlot.work),
            ),
          ],
        ),

        const _Section(
          title: 'Payments',
          children: [
            _Row(
              icon: Icons.payments_rounded,
              title: 'Cash',
              value: 'Default payment method',
              trailing: Icon(
                Icons.check_circle_rounded,
                color: RarColors.success,
              ),
            ),
            _Row(
              icon: Icons.credit_card_rounded,
              title: 'Cards and wallet',
              value: 'Coming with the payments update (Paystack, Flutterwave)',
            ),
          ],
        ),

        _Section(
          title: 'Preferences',
          children: [
            _SwitchRow(
              icon: Icons.notifications_active_rounded,
              title: 'Ride updates',
              value: 'Driver arriving, trip started, receipts',
              on: _rideAlerts,
              onChanged: (v) => setState(() => _rideAlerts = v),
            ),
            _SwitchRow(
              icon: Icons.local_offer_rounded,
              title: 'Offers and promotions',
              value: 'Discounts and new features',
              on: _promotions,
              onChanged: (v) => setState(() => _promotions = v),
            ),
          ],
        ),

        _Section(
          title: 'Updates',
          children: [
            _Row(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              value: () {
                final unread = (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length;
                return unread == 0 ? 'Trip updates and news from Rent A Ride' : '$unread new';
              }(),
              highlight: (ref.watch(notificationsProvider).value ?? const []).any((n) => !n.read),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NotificationsScreen())),
            ),
          ],
        ),

        _Section(
          title: 'Help',
          children: [
            _Row(
              icon: Icons.support_agent_rounded,
              title: 'Message Support',
              value: 'Rides, fares, payments and your account',
              onTap: () => openChat(context, MessagesController.supportId),
            ),
            _Row(
              icon: Icons.report_rounded,
              title: 'Report a safety issue',
              value: 'Message our safety team',
              onTap: () => openChat(context, MessagesController.safetyId),
            ),
          ],
        ),

        const SizedBox(height: RarSpacing.xl),
        RarButton.outline(
          label: 'Sign out',
          leadingIcon: Icons.logout_rounded,
          isLoading: _signingOut,
          onPressed: _confirmSignOut,
        ),
        const SizedBox(height: RarSpacing.lg),
        Center(
          child: Text(
            'Rent A Ride · demo build',
            style: RarTypography.caption.copyWith(color: RarColors.textMuted),
          ),
        ),
      ],
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: RarColors.glassFillDarkStrong,
      borderRadius: RarRadius.pillShape,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: RarColors.cyan),
        const SizedBox(width: 4),
        Text(
          label,
          style: RarTypography.caption.copyWith(color: RarColors.white),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: RarSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: RarSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: RarTypography.caption.copyWith(
              color: RarColors.textSecondary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: RarColors.white,
            borderRadius: RarRadius.card,
            border: Border.all(color: RarColors.outlineLight),
          ),
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: RarColors.outlineLight,
                  ),
                child,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.trailing,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: RarColors.royal),
    title: Text(title, style: RarTypography.titleSmall.copyWith(fontSize: 14)),
    subtitle: Text(
      value,
      style: RarTypography.bodySmall.copyWith(
        color: highlight ? RarColors.royal : RarColors.textSecondary,
      ),
    ),
    trailing:
        trailing ??
        (onTap == null
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                color: RarColors.textMuted,
              )),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.on,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool on;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon, color: RarColors.royal),
    title: Text(title, style: RarTypography.titleSmall.copyWith(fontSize: 14)),
    subtitle: Text(
      enabled ? value : 'Add an emergency contact first',
      style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary),
    ),
    value: on && enabled,
    onChanged: enabled ? onChanged : null,
    activeThumbColor: RarColors.royal,
  );
}

class _FieldSpec {
  const _FieldSpec({
    required this.label,
    required this.initial,
    required this.icon,
    required this.validator,
    this.keyboard,
  });

  final String label;
  final String initial;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboard;
}

/// Bottom sheet with a small form. Pops `true` once [onSave] succeeds.
class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.title,
    required this.fields,
    required this.onSave,
    this.note,
  });

  final String title;
  final String? note;
  final List<_FieldSpec> fields;
  final Future<void> Function(List<String> values) onSave;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _form = GlobalKey<FormState>();
  late final _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave([for (final c in _controllers) c.text]);
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: RarTypography.headline),
            if (widget.note != null) ...[
              const SizedBox(height: RarSpacing.sm),
              Text(
                widget.note!,
                style: RarTypography.bodySmall.copyWith(
                  color: RarColors.textSecondary,
                ),
              ),
            ],
            for (final (i, f) in widget.fields.indexed) ...[
              const SizedBox(height: RarSpacing.lg),
              RarTextField(
                label: f.label,
                controller: _controllers[i],
                prefixIcon: f.icon,
                keyboardType: f.keyboard,
                validator: f.validator,
                autofocus: i == 0,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: RarSpacing.md),
              RarInlineMessage.error(_error!),
            ],
            const SizedBox(height: RarSpacing.xl),
            RarButton.primary(
              label: 'Save',
              isLoading: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
