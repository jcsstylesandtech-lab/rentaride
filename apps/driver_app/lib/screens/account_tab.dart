import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rar_chat/rar_chat.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../core/format.dart';
import '../state/app_control.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RarColors.navy900,
        title: const Text('Sign out?'),
        content: const Text("You'll go offline and stop receiving ride requests."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(repoProvider);
    try { await repo.setOnline(false); } catch (_) {}
    await repo.signOut();
  }

  Widget _helpTile(BuildContext context,
      {required String key,
      required IconData icon,
      required String title,
      required String subtitle,
      required String kind,
      required String intro}) {
    return ListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: RarColors.cyan),
      title: Text(title, style: RarTypography.body.copyWith(color: RarColors.white)),
      subtitle: Text(subtitle, style: onDarkMuted),
      trailing: const Icon(Icons.chevron_right_rounded, color: RarColors.textOnDarkMuted),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LiveChatScreen(
          title: title,
          subtitle: subtitle,
          icon: icon,
          peerLabel: kind == 'safety' ? 'Safety team' : 'Support',
          intro: intro,
          dark: true,
          open: () => openTeamConversation(Supabase.instance.client, kind),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(driverStateProvider).value;
    if (s == null) return const SizedBox.shrink();
    final p = s.profile;
    final v = s.vehicles.isEmpty ? null : s.vehicles.first;
    final docs = s.latestDocs.values.toList();

    Widget row(IconData icon, String label, String value, {Widget? trailing}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: RarColors.cyan),
          title: Text(label, style: onDarkMuted),
          subtitle: Text(value, style: RarTypography.body.copyWith(color: RarColors.white)),
          trailing: trailing,
        );

    return RefreshIndicator(
      color: RarColors.cyan,
      onRefresh: () async {
        ref.invalidate(driverStateProvider);
        try {
          await ref.read(driverStateProvider.future);
        } catch (_) {} // the tab keeps showing the last good details
      },
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      const SizedBox(height: RarSpacing.md),
      Panel(child: Row(children: [
        _ProfilePhoto(name: p?.fullName ?? '', url: p?.avatarUrl),
        const SizedBox(width: RarSpacing.lg),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p?.fullName ?? '', style: RarTypography.title.copyWith(color: RarColors.white)),
          Text(p?.email ?? '', style: onDarkMuted),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.star_rounded, color: RarColors.warning, size: 18),
            Text(' ${p?.ratingAvg.toStringAsFixed(2)} (${p?.ratingCount} ratings)',
                style: RarTypography.bodySmall.copyWith(color: RarColors.white)),
            const SizedBox(width: RarSpacing.sm),
            const StatusChip('approved'),
          ]),
        ])),
      ])),
      const SizedBox(height: RarSpacing.lg),
      Panel(child: Column(children: [
        row(Icons.badge_rounded, "Driver's licence", s.driver?.licenceNumber ?? '—'),
        if (s.driver?.homeAddress?.isNotEmpty == true) row(Icons.home_rounded, 'Home address', s.driver!.homeAddress!),
        if (v != null) row(Icons.directions_car_rounded, 'Vehicle', '${v.title} · ${v.plateNumber}', trailing: StatusChip(v.review)),
        if (v != null) row(Icons.category_rounded, 'Ride type', titleCase(v.vehicleClass.name == 'suv' ? 'SUV' : v.vehicleClass.name)),
      ])),
      const SizedBox(height: RarSpacing.lg),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: RarSpacing.lg, vertical: RarSpacing.xs),
        child: ListTile(
          key: const ValueKey('open-notifications'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_rounded, color: RarColors.cyan),
          title: Text('Notifications', style: RarTypography.body.copyWith(color: RarColors.white)),
          subtitle: Text(() {
            final unread = (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length;
            return unread == 0 ? 'Trip updates and messages from Rent A Ride' : '$unread new';
          }(), style: onDarkMuted),
          trailing: const Icon(Icons.chevron_right_rounded, color: RarColors.textOnDarkMuted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen())),
        ),
      ),
      const SizedBox(height: RarSpacing.lg),
      // Help from the Rent A Ride team; replies from the dashboard arrive live.
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: RarSpacing.lg, vertical: RarSpacing.xs),
        child: Column(children: [
          _helpTile(context,
              key: 'open-support-chat',
              icon: Icons.support_agent_rounded,
              title: 'Driver support',
              subtitle: 'Trips, earnings, payouts and your account',
              kind: 'support',
              intro: 'Hi ${p?.fullName.split(' ').first ?? 'there'}, need help? Message the Rent A Ride '
                  'driver team about trips, earnings, payouts or your account.'),
          const Divider(height: 1, color: RarColors.glassBorderDark),
          _helpTile(context,
              key: 'open-safety-chat',
              icon: Icons.shield_rounded,
              title: 'Safety team',
              subtitle: 'Report an incident or a safety concern',
              kind: 'safety',
              intro: 'If you are in danger, call 112 first. To report an incident after a trip, '
                  'tell us the date, time and what happened.'),
        ]),
      ),
      const SizedBox(height: RarSpacing.lg),
      Text('Documents', style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
      const SizedBox(height: RarSpacing.sm),
      Panel(child: Column(children: [
        for (final d in docs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(d.type.label, style: RarTypography.bodySmall.copyWith(color: RarColors.white))),
              StatusChip(d.review),
            ]),
          ),
      ])),
      const SizedBox(height: RarSpacing.sm),
      Text('To change your licence or documents after approval, contact support from the passenger app or email support.',
          style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
      const SizedBox(height: RarSpacing.xl),
      RarButton.glass(label: 'Sign out', leadingIcon: Icons.logout_rounded, onPressed: () => _signOut(context, ref)),
      const SizedBox(height: RarSpacing.xxl),
    ]),
    );
  }
}

/// The driver's photo; tap to take, choose or remove one.
class _ProfilePhoto extends ConsumerStatefulWidget {
  const _ProfilePhoto({required this.name, required this.url});
  final String name;
  final String? url;

  @override
  ConsumerState<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends ConsumerState<_ProfilePhoto> {
  bool _busy = false;

  Future<void> _change() async {
    final choice = await showPhotoSourceSheet(context, hasPhoto: widget.url != null, cameraAvailable: !kIsWeb);
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(repoProvider);
      if (choice == PhotoSourceChoice.remove) {
        await repo.removeAvatar();
        if (mounted) showSnack(context, 'Profile photo removed');
      } else {
        final file = await ImagePicker().pickImage(
          source: choice == PhotoSourceChoice.camera ? ImageSource.camera : ImageSource.gallery,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 800, maxHeight: 800, imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) showSnack(context, 'That photo is too large. Choose one under 5 MB.', error: true);
          return;
        }
        await repo.uploadAvatar(bytes, file.name.contains('.') ? file.name.split('.').last : 'jpg');
        if (mounted) showSnack(context, 'Profile photo updated');
      }
      ref.invalidate(driverStateProvider);
    } on PlatformException catch (e) {
      if (mounted) {
        showSnack(context, e.code.contains('camera') ? 'Camera not available here. Choose from photos.' : friendlyError(e),
            error: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RarAvatar(
        key: const ValueKey('profile-photo'),
        name: widget.name,
        imageUrl: widget.url,
        busy: _busy,
        onEdit: _change,
      );
}
