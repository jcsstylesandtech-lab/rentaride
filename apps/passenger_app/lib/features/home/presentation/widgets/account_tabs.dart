import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rar_design_system/rar_design_system.dart';

/// A scrolling tab page with a large title (Rides, Messages, Wallet,
/// Profile).
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: SafeArea(
      bottom: false,
      child: RarContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            RarSpacing.gutter,
            RarSpacing.lg,
            RarSpacing.gutter,
            RarSpacing.xxxl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: RarTypography.headlineLarge),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: RarSpacing.xl),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Icon, title, explanation and an optional action, for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        IconTile(icon: icon, size: 64),
        const SizedBox(height: RarSpacing.lg),
        Text(title, style: RarTypography.title, textAlign: TextAlign.center),
        const SizedBox(height: RarSpacing.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: RarTypography.body.copyWith(color: RarColors.textSecondary),
        ),
        if (action != null) ...[const SizedBox(height: RarSpacing.xl), action!],
      ],
    ),
  );
}

/// Trip history (empty until rides can be booked).
class RidesTab extends StatelessWidget {
  const RidesTab({super.key, required this.onBookRide});
  final VoidCallback onBookRide;

  @override
  Widget build(BuildContext context) => TabPage(
    title: 'Your rides',
    children: [
      EmptyState(
        icon: Icons.directions_car_rounded,
        title: 'No rides yet',
        body: 'Your trips, receipts and driver ratings will appear here.',
        action: RarButton.primary(
          label: 'Book a ride',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: onBookRide,
        ),
      ),
    ],
  );
}

/// Wallet balance and transactions. Funding arrives with Paystack /
/// Flutterwave in the payments phase.
class WalletTab extends StatelessWidget {
  const WalletTab({super.key});

  @override
  Widget build(BuildContext context) => TabPage(
    title: 'Wallet',
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [RarColors.navy700, RarColors.navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: RarRadius.card,
          boxShadow: RarShadows.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available balance',
              style: RarTypography.bodySmall.copyWith(
                color: RarColors.textOnDarkSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₦0.00',
              style: RarTypography.headlineLarge.copyWith(
                color: RarColors.white,
              ),
            ),
            const SizedBox(height: RarSpacing.md),
            Text(
              'Pay with cash for now. Card payments and wallet top-ups '
              'with Paystack and Flutterwave come with the payments '
              'update.',
              style: RarTypography.bodySmall.copyWith(
                color: RarColors.textOnDarkSecondary,
              ),
            ),
          ],
        ),
      ),
      const EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No transactions yet',
        body: 'Payments, top-ups and refunds will be listed here.',
      ),
    ],
  );
}
