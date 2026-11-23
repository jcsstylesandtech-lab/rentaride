import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

final _tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(repoProvider).completedTrips(days: 30));

class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(_tripsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    return RefreshIndicator(
      color: RarColors.cyan,
      onRefresh: () async => ref.invalidate(_tripsProvider),
      child: ListView(children: [
        const SizedBox(height: RarSpacing.md),
        Text('Earnings', style: RarTypography.headlineLarge.copyWith(color: RarColors.white)),
        const SizedBox(height: RarSpacing.lg),
        trips.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: RarColors.cyan))),
          error: (e, _) => Panel(child: Text(friendlyError(e), style: onDarkMuted)),
          data: (list) {
            int sum(Iterable<Trip> t) => t.fold(0, (s, x) => s + x.fare);
            final todayTrips = list.where((t) => t.completedAt!.toLocal().isAfter(today));
            final weekTrips = list.where((t) => t.completedAt!.toLocal().isAfter(weekStart));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(RarSpacing.xl),
                decoration: BoxDecoration(gradient: RarGradients.primaryButton, borderRadius: RarRadius.card),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today', style: RarTypography.bodySmall.copyWith(color: RarColors.white.withValues(alpha: 0.8))),
                  Text(naira(sum(todayTrips)), style: RarTypography.display.copyWith(color: RarColors.white, fontSize: 36)),
                  Text('${todayTrips.length} trips', style: RarTypography.bodySmall.copyWith(color: RarColors.white)),
                ]),
              ),
              const SizedBox(height: RarSpacing.md),
              Row(children: [
                Expanded(child: _Stat(label: 'This week', value: naira(sum(weekTrips)), sub: '${weekTrips.length} trips')),
                const SizedBox(width: RarSpacing.md),
                Expanded(child: _Stat(label: 'Last 30 days', value: naira(sum(list)), sub: '${list.length} trips')),
              ]),
              const SizedBox(height: RarSpacing.sm),
              Text('Fares shown are what riders paid. Cash trips: you collect the fare directly.',
                  style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
              const SizedBox(height: RarSpacing.lg),
              Text('Recent trips', style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
              const SizedBox(height: RarSpacing.sm),
              if (list.isEmpty) Panel(child: Text('Completed trips will appear here.', style: onDarkMuted)),
              for (final t in list.take(50))
                Padding(
                  padding: const EdgeInsets.only(bottom: RarSpacing.sm),
                  child: Panel(
                    padding: const EdgeInsets.all(RarSpacing.md),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: RarTypography.bodySmall.copyWith(color: RarColors.white, fontWeight: FontWeight.w600)),
                        Text('${timeAgo(t.completedAt!.toLocal())} · ${km(t.distanceM)} · ${titleCase(t.paymentMethod)}', style: onDarkMuted),
                      ])),
                      Text(naira(t.fare), style: RarTypography.titleSmall.copyWith(color: RarColors.cyan)),
                    ]),
                  ),
                ),
            ]);
          },
        ),
        const SizedBox(height: RarSpacing.xxl),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;
  @override
  Widget build(BuildContext context) => Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: onDarkMuted),
        Text(value, style: RarTypography.title.copyWith(color: RarColors.white)),
        Text(sub, style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
      ]));
}
