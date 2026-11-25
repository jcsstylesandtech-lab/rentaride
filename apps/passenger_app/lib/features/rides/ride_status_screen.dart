import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, RealtimeChannel;

import '../home/presentation/controllers/home_providers.dart';
import 'ride_models.dart';
import 'searching_card.dart';

/// Follows one ride live: finding a driver / offers → driver on the way →
/// on trip → rate. Updates come from Supabase Realtime (with a slow poll as
/// a safety net).
class RideStatusScreen extends ConsumerStatefulWidget {
  const RideStatusScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<RideStatusScreen> createState() => _RideStatusScreenState();
}

class _RideStatusScreenState extends ConsumerState<RideStatusScreen> {
  PassengerRide? _ride;
  List<DriverOffer> _offers = const [];
  AssignedDriver? _driver;
  RealtimeChannel? _channel;
  Timer? _poll;
  Timer? _searchPoll;
  SearchStatus? _search;
  DateTime _searchAt = DateTime.now();
  String? _error;
  String? _busy;
  bool _rated = false;
  bool _sosSent = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(ridesRepositoryProvider);
    _channel = repo.watch(widget.rideId, () { if (mounted) _load(); });
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    _searchPoll = Timer.periodic(const Duration(seconds: 5), (_) => _loadSearch());
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchPoll?.cancel();
    final c = _channel;
    if (c != null) ref.read(ridesRepositoryProvider).unwatch(c);
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(ridesRepositoryProvider);
    try {
      final ride = await repo.ride(widget.rideId);
      final offers = ride.status == 'requested' && ride.negotiable ? await repo.offers(ride.id) : const <DriverOffer>[];
      final driver = ride.hasDriver && _driver == null ? await repo.driver(ride.id) : _driver;
      if (!mounted) return;
      if (_ride != null && _ride!.status != ride.status) HapticFeedback.mediumImpact();
      setState(() { _ride = ride; _offers = offers; _driver = driver; _error = null; });
      if (!ride.isOpen) _poll?.cancel();
      if (ride.status != 'requested') {
        _searchPoll?.cancel();
      } else if (_search == null) {
        _loadSearch();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Reconnecting…');
    }
  }

  /// Search area and drivers in range, only while still waiting for one.
  Future<void> _loadSearch() async {
    final ride = _ride;
    if (ride == null || ride.status != 'requested') return;
    try {
      final s = await ref.read(ridesRepositoryProvider).searchStatus(ride.id);
      if (mounted) setState(() { _search = s; _searchAt = DateTime.now(); });
    } catch (_) {/* the card keeps counting; next poll retries */}
  }

  Future<void> _act(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Future<void> _cancel() async {
    const reasons = ['Driver is taking too long', 'I changed my plans', 'Booked by mistake', 'Found another ride'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RarColors.white,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Why are you cancelling?', style: TextStyle(fontWeight: FontWeight.w600))),
        for (final r in reasons) ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
      ])),
    );
    if (reason != null) await _act('cancel', () => ref.read(ridesRepositoryProvider).cancel(widget.rideId, reason));
  }

  Future<void> _sos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sos_rounded, color: RarColors.danger, size: 40),
        title: const Text('Send an SOS?'),
        content: const Text('Our safety team gets your trip details and location immediately. '
            'If you are in immediate danger, also call 112.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: RarColors.danger),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Send SOS')),
        ],
      ),
    );
    if (ok != true || _ride == null) return;
    await _act('sos', () async {
      await ref.read(ridesRepositoryProvider).sos(_ride!);
      _sosSent = true;
    });
    if (_sosSent && mounted) _snack('SOS sent. Our safety team has been alerted.');
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    return Theme(
      data: RarTheme.light(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: RarColors.background,
          appBar: AppBar(
            title: Text(ride?.isDelivery == true ? 'Your delivery' : 'Your ride'),
            actions: [
              if (ride != null && const {'accepted', 'driver_arrived', 'in_progress'}.contains(ride.status))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    key: const ValueKey('sos'),
                    style: FilledButton.styleFrom(backgroundColor: RarColors.danger),
                    onPressed: _busy == 'sos' ? null : _sos,
                    icon: const Icon(Icons.sos_rounded, size: 18),
                    label: Text(_sosSent ? 'SOS sent' : 'SOS'),
                  ),
                ),
            ],
          ),
          body: ride == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(RarSpacing.lg), children: [
                  if (_error != null) ...[RarInlineMessage.info(_error!), const SizedBox(height: RarSpacing.md)],
                  _Header(ride: ride, offers: _offers.length),
                  const SizedBox(height: RarSpacing.lg),
                  _RouteCard(ride: ride),
                  const SizedBox(height: RarSpacing.lg),
                  ..._body(ride),
                ]),
        ),
      ),
    );
  }

  List<Widget> _body(PassengerRide ride) {
    switch (ride.status) {
      case 'requested':
        return [
          if (ride.negotiable) ...[
            if (_offers.isEmpty)
              SearchingCard(ride: ride, status: _search, fetchedAt: _searchAt)
            else
              Text('Pick an offer', style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
            const SizedBox(height: RarSpacing.sm),
            for (final o in _offers)
              _OfferTile(offer: o, yourOffer: ride.offeredKobo, busy: _busy == o.id,
                  onAccept: () => _act(o.id, () => ref.read(ridesRepositoryProvider).acceptOffer(o.id))),
          ] else ...[
            SearchingCard(ride: ride, status: _search, fetchedAt: _searchAt),
            if (ride.isDelivery) ...[
              const SizedBox(height: RarSpacing.md),
              _PackageCard(ride: ride),
            ],
          ],
          const SizedBox(height: RarSpacing.xl),
          RarButton.outline(label: 'Cancel request', isLoading: _busy == 'cancel', onPressed: _busy != null ? null : _cancel),
        ];
      case 'accepted' || 'driver_arrived' || 'in_progress':
        return [
          _DriverCard(driver: _driver),
          const SizedBox(height: RarSpacing.md),
          if (ride.isDelivery) ...[
            _PackageCard(ride: ride),
            const SizedBox(height: RarSpacing.sm),
            _InfoRow(icon: Icons.payments_rounded, text: 'Pay ${nairaKobo(ride.fareKobo)} in cash when the ${ride.courier} collects the package.'),
            _InfoRow(icon: Icons.shield_rounded, text: 'Check the plate number before you hand it over. Tap SOS if anything feels wrong.'),
          ] else ...[
            _InfoRow(icon: Icons.payments_rounded, text: 'Pay ${nairaKobo(ride.fareKobo)} in cash at the end of the trip.'),
            _InfoRow(icon: Icons.shield_rounded, text: 'Check the plate number before you get in. Tap SOS at any time if you feel unsafe.'),
          ],
          if (ride.status != 'in_progress') ...[
            const SizedBox(height: RarSpacing.xl),
            RarButton.outline(label: 'Cancel ride', isLoading: _busy == 'cancel', onPressed: _busy != null ? null : _cancel),
          ],
        ];
      case 'completed':
        return [
          _DriverCard(driver: _driver),
          const SizedBox(height: RarSpacing.lg),
          if (_rated)
            const RarInlineMessage.success('Thanks for rating your driver!')
          else
            _RateCard(driverName: _driver?.name ?? 'your driver', busy: _busy == 'rate',
                onSubmit: (stars, comment) => _act('rate', () async {
                  await ref.read(ridesRepositoryProvider).rateDriver(ride, stars, comment);
                  _rated = true;
                })),
          const SizedBox(height: RarSpacing.lg),
          RarButton.primary(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        ];
      default:
        return [
          RarInlineMessage.info(ride.cancelReason ?? 'This ride was cancelled.'),
          const SizedBox(height: RarSpacing.lg),
          RarButton.primary(label: 'Back to map', onPressed: () => Navigator.of(context).pop()),
        ];
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ride, required this.offers});
  final PassengerRide ride;
  final int offers;

  @override
  Widget build(BuildContext context) {
    if (ride.isDelivery) {
      final (IconData icon, String title, String sub) = switch (ride.status) {
        'requested' => (Icons.search_rounded, 'Finding a ${ride.courier}', '${ride.optionLabel} · ${nairaKobo(ride.estimatedKobo)}'),
        'accepted' => (ride.delivery?.icon ?? Icons.local_shipping_rounded, 'Coming to collect', 'Have the package ready at the pickup point.'),
        'driver_arrived' => (Icons.place_rounded, 'Your ${ride.courier} is here', 'Hand over the package.'),
        'in_progress' => (Icons.route_rounded, 'On the way to ${ride.recipientName ?? 'the recipient'}', 'We will show here when it is delivered.'),
        'completed' => (Icons.check_circle_rounded, 'Delivered', 'Fare ${nairaKobo(ride.fareKobo)}'),
        _ => (Icons.cancel_rounded, 'Delivery cancelled', 'No charge.'),
      };
      return _banner(icon, title, sub);
    }
    final (IconData icon, String title, String sub) = switch (ride.status) {
      'requested' when ride.negotiable => (Icons.handshake_rounded, 'Offer sent: ${nairaKobo(ride.offeredKobo ?? ride.estimatedKobo)}',
          offers == 0 ? 'Drivers nearby can accept or counter your price.' : '$offers driver${offers == 1 ? '' : 's'} responded.'),
      'requested' => (Icons.search_rounded, 'Finding your driver', '${ride.option.label} · fixed fare ${nairaKobo(ride.estimatedKobo)}'),
      'accepted' => (Icons.directions_car_rounded, 'Driver on the way', 'Be ready at your pickup point.'),
      'driver_arrived' => (Icons.place_rounded, 'Your driver has arrived', 'Meet them at the pickup point.'),
      'in_progress' => (Icons.route_rounded, 'On your way', 'Enjoy the ride.'),
      'completed' => (Icons.check_circle_rounded, 'You have arrived', 'Trip fare ${nairaKobo(ride.fareKobo)}'),
      _ => (Icons.cancel_rounded, 'Ride cancelled', 'No charge.'),
    };
    return _banner(icon, title, sub);
  }

  Widget _banner(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(RarSpacing.lg),
      decoration: BoxDecoration(gradient: RarGradients.primaryButton, borderRadius: RarRadius.card),
      child: Row(children: [
        Icon(icon, color: RarColors.white, size: 34),
        const SizedBox(width: RarSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: RarTypography.title.copyWith(color: RarColors.white)),
          Text(sub, style: RarTypography.bodySmall.copyWith(color: RarColors.white.withValues(alpha: 0.85))),
        ])),
      ]),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.ride});
  final PassengerRide ride;
  @override
  Widget build(BuildContext context) => _Card(child: Column(children: [
        _InfoRow(icon: Icons.trip_origin_rounded, text: ride.pickupAddress, color: RarColors.royal),
        _InfoRow(icon: Icons.location_on_rounded, text: ride.dropoffAddress, color: RarColors.danger),
      ]));
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});
  final AssignedDriver? driver;
  @override
  Widget build(BuildContext context) {
    final d = driver;
    return _Card(
      child: d == null
          ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          : Row(children: [
              CircleAvatar(radius: 26, backgroundColor: RarColors.royal,
                  child: Text(d.name.isEmpty ? '?' : d.name[0], style: RarTypography.title.copyWith(color: RarColors.white))),
              const SizedBox(width: RarSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                Text('★ ${d.rating.toStringAsFixed(1)} · ${d.vehicle}', style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: RarColors.surfaceLight, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: RarColors.navy)),
                child: Text(d.plate, style: RarTypography.label.copyWith(color: RarColors.navy, letterSpacing: 1)),
              ),
            ]),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.yourOffer, required this.busy, required this.onAccept});
  final DriverOffer offer;
  final int? yourOffer;
  final bool busy;
  final VoidCallback onAccept;
  @override
  Widget build(BuildContext context) {
    final diff = yourOffer == null ? 0 : offer.amountKobo - yourOffer!;
    return Padding(
      padding: const EdgeInsets.only(bottom: RarSpacing.sm),
      child: _Card(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nairaKobo(offer.amountKobo), style: RarTypography.headline.copyWith(color: RarColors.navy)),
          if (diff != 0)
            Text('${diff > 0 ? '+' : '−'}${nairaKobo(diff.abs())} vs your offer',
                style: RarTypography.caption.copyWith(color: diff > 0 ? RarColors.warning : RarColors.success)),
          Text('${offer.driverName} · ★ ${offer.rating.toStringAsFixed(1)} (${offer.ratingCount})',
              style: RarTypography.bodySmall.copyWith(color: RarColors.navy)),
          Text('${offer.vehicle}${offer.etaMinutes == null ? '' : ' · ${offer.etaMinutes} min away'}',
              style: RarTypography.caption.copyWith(color: RarColors.textSecondary)),
        ])),
        FilledButton(onPressed: busy ? null : onAccept,
            child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accept')),
      ])),
    );
  }
}

class _RateCard extends StatefulWidget {
  const _RateCard({required this.driverName, required this.busy, required this.onSubmit});
  final String driverName;
  final bool busy;
  final void Function(int stars, String? comment) onSubmit;
  @override
  State<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<_RateCard> {
  int _stars = 5;
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Card(child: Column(children: [
        Text('How was your trip with ${widget.driverName}?', style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(tooltip: '$i star${i == 1 ? '' : 's'}', onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: RarColors.warning, size: 34)),
        ]),
        TextField(controller: _comment, maxLength: 500, decoration: const InputDecoration(hintText: 'Add a comment (optional)')),
        const SizedBox(height: RarSpacing.sm),
        SizedBox(width: double.infinity, child: FilledButton(
            onPressed: widget.busy ? null : () => widget.onSubmit(_stars, _comment.text), child: const Text('Submit rating'))),
      ]));
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RarSpacing.md),
        decoration: BoxDecoration(color: RarColors.white, borderRadius: RarRadius.card, border: Border.all(color: RarColors.outlineLight)),
        child: child,
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color = RarColors.textSecondary});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: RarSpacing.sm),
          Expanded(child: Text(text, style: RarTypography.bodySmall.copyWith(color: RarColors.navy))),
        ]),
      );
}

/// Who gets the package, and what it is.
class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.ride});
  final PassengerRide ride;
  @override
  Widget build(BuildContext context) => _Card(child: Column(children: [
        _InfoRow(icon: Icons.person_pin_circle_rounded, color: RarColors.royal,
            text: 'For ${ride.recipientName ?? 'the recipient'}'),
        _InfoRow(icon: Icons.inventory_2_rounded, color: RarColors.royal,
            text: '${ride.packageSize?.label ?? 'Package'} package · ${ride.optionLabel}'),
      ]));
}
