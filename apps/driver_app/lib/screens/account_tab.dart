import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

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

    return ListView(children: [
      const SizedBox(height: RarSpacing.md),
      Panel(child: Row(children: [
        CircleAvatar(radius: 30, backgroundColor: RarColors.royal,
            child: Text((p?.fullName.isNotEmpty ?? false) ? p!.fullName[0].toUpperCase() : '?',
                style: RarTypography.headline.copyWith(color: RarColors.white))),
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
    ]);
  }
}
