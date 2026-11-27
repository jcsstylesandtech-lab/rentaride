import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../rides/ride_models.dart';
import '../../../rides/ride_status_screen.dart';
import '../controllers/home_providers.dart';

/// A scrolling tab page with a large title (Rides, Messages, Wallet,
/// Profile).
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Pull down to reload. The spinner stays until the future completes.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: SafeArea(
      bottom: false,
      child: RarContentWidth(
        child: _pullToRefresh(ListView(
          // Always scrollable, so short pages can still be pulled down.
          physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
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
        )),
      ),
    ),
  );

  Widget _pullToRefresh(Widget list) {
    final refresh = onRefresh;
    if (refresh == null) return list;
    return RefreshIndicator(
      color: RarColors.royal,
      onRefresh: () async {
        try {
          await refresh();
        } catch (_) {
          // The page shows its own error state; just stop the spinner.
        }
      },
      child: list,
    );
  }
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
/// Past and current rides from the passenger's account.
final rideHistoryProvider = FutureProvider.autoDispose<List<PassengerRide>>(
  (ref) => AppConfig.hasBackend ? ref.read(ridesRepositoryProvider).history() : Future.value(const []),
);

class RidesTab extends ConsumerWidget {
  const RidesTab({super.key, required this.onBookRide});
  final VoidCallback onBookRide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(rideHistoryProvider);
    final empty = EmptyState(
      icon: Icons.directions_car_rounded,
      title: 'No rides yet',
      body: 'Your trips, receipts and driver ratings will appear here.',
      action: RarButton.primary(
        label: 'Book a ride',
        trailingIcon: Icons.arrow_forward_rounded,
        onPressed: onBookRide,
      ),
    );
    return TabPage(
      title: 'Your rides',
      onRefresh: () => ref.refresh(rideHistoryProvider.future),
      children: history.when(
        loading: () => const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))],
        error: (_, _) => [
          EmptyState(
            icon: Icons.wifi_off_rounded,
            title: "Couldn't load your rides",
            body: 'Check your connection and try again.',
            action: RarButton.outline(label: 'Try again', onPressed: () => ref.invalidate(rideHistoryProvider)),
          ),
        ],
        data: (rides) => rides.isEmpty
            ? [empty]
            : [
                for (final r in rides)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RarSpacing.sm),
                    child: Material(
                      color: RarColors.white,
                      borderRadius: RarRadius.card,
                      child: InkWell(
                        borderRadius: RarRadius.card,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => RideStatusScreen(rideId: r.id)))
                            .then((_) => ref.invalidate(rideHistoryProvider)),
                        child: Container(
                          padding: const EdgeInsets.all(RarSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: RarRadius.card,
                            border: Border.all(color: RarColors.outlineLight),
                          ),
                          child: Row(children: [
                            Icon(r.delivery?.icon ?? r.option.icon, color: RarColors.royal),
                            const SizedBox(width: RarSpacing.md),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                                Text(
                                  '${_date(r.requestedAt)} · ${r.optionLabel} · ${r.status.replaceAll('_', ' ')}',
                                  style: RarTypography.caption.copyWith(color: RarColors.textSecondary),
                                ),
                              ]),
                            ),
                            Text(nairaKobo(r.fareKobo),
                                style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
      ),
    );
  }

  static String _date(DateTime t) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = t.toLocal();
    return '${l.day} ${m[l.month - 1]}, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

