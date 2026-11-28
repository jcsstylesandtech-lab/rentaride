import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rar_chat/rar_chat.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../state/maps_config.dart';
import '../widgets/common.dart';
import '../widgets/drive_map.dart';

class DriveTab extends ConsumerStatefulWidget {
  const DriveTab({super.key});
  @override
  ConsumerState<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends ConsumerState<DriveTab> {
  bool _online = false;
  bool _switching = false;
  String? _locationProblem;
  StreamSubscription<Position>? _positions;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _poll;
  RealtimeChannel? _channel;

  List<RideRequest>? _requests;
  List<MyOffer> _offers = [];
  Trip? _trip;
  ({double lat, double lng})? _me;
  ({String name, double rating})? _passenger;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    final s = ref.read(driverStateProvider).value;
    _channel = ref.read(repoProvider).watchMine(() { if (mounted) _refresh(); });
    _refresh();
    if (s?.driver?.isOnline == true) _goOnline(); // resume after app restart
  }

  @override
  void dispose() {
    _positions?.cancel();
    _poll?.cancel();
    final c = _channel;
    if (c != null) ref.read(repoProvider).unwatch(c);
    super.dispose();
  }

  Future<void> _refresh() async {
    final repo = ref.read(repoProvider);
    try {
      final trip = await repo.activeTrip();
      final offers = await repo.myPendingOffers();
      List<RideRequest>? requests;
      if (_online && trip == null) requests = await repo.openRequests();
      if (!mounted) return;
      if (trip?.id != _trip?.id) {
        _passenger = null;
        if (trip != null) repo.passengerFor(trip.id).then((p) { if (mounted) setState(() => _passenger = p); });
      }
      setState(() {
        _trip = trip;
        _offers = offers;
        _requests = requests ?? (_online ? _requests : null);
      });
    } catch (e) {
      if (mounted && _online) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<bool> _ensureLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _locationProblem = 'Turn on Location Services to go online.');
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      setState(() => _locationProblem = 'Allow location access in Settings so riders can find you.');
      return false;
    }
    setState(() => _locationProblem = null);
    return true;
  }

  Future<void> _sendPosition(Position p, {bool force = false}) async {
    if (mounted && _me == null) setState(() => _me = (lat: p.latitude, lng: p.longitude));
    if (!force && DateTime.now().difference(_lastSent) < const Duration(seconds: 8)) return;
    _me = (lat: p.latitude, lng: p.longitude);
    _lastSent = DateTime.now();
    try {
      await ref.read(repoProvider).reportLocation(p.latitude, p.longitude, p.heading, p.speed * 3.6);
    } catch (_) {/* next update retries */}
  }

  Future<void> _goOnline() async {
    setState(() => _switching = true);
    try {
      if (!await _ensureLocation()) return;
      final first = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      await _sendPosition(first, force: true);
      await ref.read(repoProvider).setOnline(true);
      _positions?.cancel();
      _positions = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25))
          .listen(_sendPosition);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
      setState(() => _online = true);
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _goOffline() async {
    setState(() => _switching = true);
    _positions?.cancel();
    _poll?.cancel();
    try {
      await ref.read(repoProvider).setOnline(false);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() { _online = false; _switching = false; _requests = null; });
  }

  Future<void> _run(String key, Future<void> Function() action, {String? success}) async {
    setState(() => _busy.add(key));
    try {
      await action();
      if (success != null && mounted) showSnack(context, success);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
      await _refresh();
    }
  }

  Future<void> _offer(RideRequest r) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: RarColors.navy900,
      builder: (_) => _OfferSheet(request: r),
    );
    if (amount == null) return;
    final eta = (r.pickupDistanceM / 400).ceil().clamp(1, 60);
    await _run(r.id, () => ref.read(repoProvider).makeOffer(r.id, amount, eta),
        success: 'Offer of ${naira(amount)} sent. You\'ll get the trip if ${r.passengerName} accepts.');
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final showMap = ref.watch(mapsConfiguredProvider).value == true;
    return RefreshIndicator(
      color: RarColors.cyan,
      onRefresh: _refresh,
      child: ListView(
        children: [
          const SizedBox(height: RarSpacing.md),
          _OnlineSwitch(online: _online, busy: _switching, onChanged: (v) => v ? _goOnline() : _goOffline()),
          if (_locationProblem != null) ...[
            const SizedBox(height: RarSpacing.sm),
            Panel(borderColor: RarColors.warning, child: Row(children: [
              const Icon(Icons.location_off_rounded, color: RarColors.warning),
              const SizedBox(width: RarSpacing.md),
              Expanded(child: Text(_locationProblem!, style: onDarkMuted)),
              TextButton(onPressed: Geolocator.openAppSettings, child: const Text('Settings')),
            ])),
          ],
          if (showMap && (_online || trip != null)) ...[
            const SizedBox(height: RarSpacing.md),
            DriveMap(me: _me, requests: _requests ?? const [], trip: trip),
          ],
          if (trip == null) ...[
            const SizedBox(height: RarSpacing.md),
            const _JobsChooser(),
          ],
          const SizedBox(height: RarSpacing.lg),
          if (trip != null)
            _TripCard(
              trip: trip,
              passenger: _passenger,
              busy: _busy.contains(trip.id),
              onAdvance: (status) => _run(trip.id, () async {
                await ref.read(repoProvider).advanceTrip(trip.id, status);
                if (status == 'completed' && context.mounted) {
                  final stars = await showDialog<int>(context: context, builder: (_) => _RateDialog(name: _passenger?.name ?? 'the passenger', fare: trip.fare));
                  if (stars != null) await ref.read(repoProvider).ratePassenger(trip.id, stars);
                }
              }, success: switch (status) {
                'driver_arrived' => 'Passenger notified that you\'ve arrived.',
                'in_progress' => 'Trip started. Drive safely!',
                _ => 'Trip complete — collect ${naira(trip.fare)} if paying cash.',
              }),
              onCancel: (reason) => _run(trip.id, () => ref.read(repoProvider).cancelTrip(trip.id, reason), success: 'Trip cancelled.'),
            )
          else if (!_online)
            Panel(child: Column(children: [
              const Icon(Icons.nightlight_round, color: RarColors.cyan, size: 36),
              const SizedBox(height: RarSpacing.sm),
              Text("You're offline", style: RarTypography.title.copyWith(color: RarColors.white)),
              const SizedBox(height: 4),
              Text('Go online to appear on passengers\' maps and receive ride requests.',
                  textAlign: TextAlign.center, style: onDarkMuted),
            ]))
          else ...[
            Row(children: [
              Text('Jobs near you', style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
              const Spacer(),
              if (_requests == null) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: RarColors.cyan)),
            ]),
            const SizedBox(height: RarSpacing.sm),
            if (_requests != null && _requests!.isEmpty)
              Panel(child: Column(children: [
                const Icon(Icons.radar_rounded, color: RarColors.cyan, size: 32),
                const SizedBox(height: RarSpacing.sm),
                Text('Looking for riders…', style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
                Text('New requests appear here automatically.', style: onDarkMuted),
              ])),
            for (final r in _requests ?? const <RideRequest>[])
              _RequestCard(
                request: r,
                offer: _offers.where((o) => o.rideId == r.id).firstOrNull,
                busy: _busy.contains(r.id),
                onAccept: () => _run(r.id, () => ref.read(repoProvider).acceptRide(r.id), success: 'Ride accepted — head to pickup.'),
                onOffer: () => _offer(r),
                onWithdraw: (o) => _run(r.id, () => ref.read(repoProvider).withdrawOffer(o.id), success: 'Offer withdrawn.'),
              ),
          ],
          const SizedBox(height: RarSpacing.xxl),
        ],
      ),
    );
  }
}

/// Rides / Dispatch / Delivery: the jobs this driver wants. A kind of job
/// needs an approved vehicle that fits it (motorbike for dispatch, car or
/// van for delivery).
class _JobsChooser extends ConsumerStatefulWidget {
  const _JobsChooser();
  @override
  ConsumerState<_JobsChooser> createState() => _JobsChooserState();
}

class _JobsChooserState extends ConsumerState<_JobsChooser> {
  bool _saving = false;

  Future<void> _toggle(List<ServiceType> current, ServiceType t) async {
    final next = current.contains(t) ? [...current.where((s) => s != t)] : [...current, t];
    if (next.isEmpty) {
      showSnack(context, 'Keep at least one kind of job switched on.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(repoProvider).setServices(next);
      ref.invalidate(driverStateProvider);
      if (mounted) {
        showSnack(context, current.contains(t) ? "You won't get ${t.shortLabel.toLowerCase()} jobs." : "You'll now get ${t.shortLabel.toLowerCase()} jobs too.");
      }
    } catch (_) {
      if (mounted) showSnack(context, "Couldn't save your job choice. Check your connection and try again.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(driverStateProvider).value;
    final d = s?.driver;
    if (s == null || d == null) return const SizedBox.shrink();
    final approved = {for (final v in s.vehicles) if (v.review == 'approved') v.vehicleClass};
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Jobs you take', style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
        const SizedBox(height: RarSpacing.sm),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in ServiceType.values)
            Builder(builder: (context) {
              final fits = t.vehicleClasses.any(approved.contains);
              final on = d.services.contains(t);
              return FilterChip(
                key: ValueKey('jobs-${t.name}'),
                selected: on && fits,
                showCheckmark: true,
                label: Text(t.shortLabel),
                avatar: on && fits ? null : Icon(switch (t) {
                  ServiceType.ride => Icons.directions_car_rounded,
                  ServiceType.dispatch => Icons.two_wheeler_rounded,
                  ServiceType.delivery => Icons.local_shipping_rounded,
                }, size: 18),
                selectedColor: RarColors.royal,
                onSelected: _saving || !fits ? null : (_) => _toggle(d.services, t),
              );
            }),
        ]),
        const SizedBox(height: RarSpacing.sm),
        Text(
          [
            if (!ServiceType.dispatch.vehicleClasses.any(approved.contains)) 'Dispatch needs an approved motorbike.',
            if (!ServiceType.delivery.vehicleClasses.any(approved.contains)) 'Delivery needs an approved car or van.',
            if (!ServiceType.ride.vehicleClasses.any(approved.contains)) 'Rides need an approved car.',
          ].join(' ').ifEmpty('Switch on every kind of job you want to see.'),
          style: onDarkMuted,
        ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _OnlineSwitch extends StatelessWidget {
  const _OnlineSwitch({required this.online, required this.busy, required this.onChanged});
  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(RarSpacing.lg),
      decoration: BoxDecoration(
        gradient: online ? RarGradients.primaryButton : null,
        color: online ? null : RarColors.glassFillDarkStrong,
        borderRadius: RarRadius.card,
        border: Border.all(color: online ? Colors.transparent : RarColors.glassBorderDark),
      ),
      child: Row(children: [
        Icon(online ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded, color: RarColors.white, size: 30),
        const SizedBox(width: RarSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(online ? "You're online" : "You're offline", style: RarTypography.title.copyWith(color: RarColors.white)),
          Text(online ? 'Riders nearby can see your car' : 'Tap to start receiving rides',
              style: RarTypography.bodySmall.copyWith(color: RarColors.white.withValues(alpha: 0.8))),
        ])),
        if (busy)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: RarColors.white))
        else
          Switch(key: const ValueKey('online-switch'), value: online, onChanged: onChanged,
              activeThumbColor: RarColors.white, activeTrackColor: RarColors.white.withValues(alpha: 0.35)),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.offer, required this.busy,
      required this.onAccept, required this.onOffer, required this.onWithdraw});
  final RideRequest request;
  final MyOffer? offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onOffer;
  final ValueChanged<MyOffer> onWithdraw;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final fare = r.negotiable ? r.offeredFare ?? r.estimatedFare : r.estimatedFare;
    return Padding(
      padding: const EdgeInsets.only(bottom: RarSpacing.md),
      child: Panel(
        borderColor: r.negotiable ? RarColors.cyan.withValues(alpha: 0.5) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(naira(fare), style: RarTypography.headline.copyWith(color: RarColors.white)),
            const SizedBox(width: RarSpacing.sm),
            StatusChip(r.negotiable ? 'passenger offer' : 'fixed fare'),
            const Spacer(),
            Text('${km(r.pickupDistanceM)} away', style: RarTypography.caption.copyWith(color: RarColors.cyan)),
          ]),
          if (r.negotiable)
            Text('Estimate ${naira(r.estimatedFare)}', style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
          const SizedBox(height: RarSpacing.sm),
          _Place(icon: Icons.trip_origin_rounded, color: RarColors.cyan, text: r.pickupAddress),
          _Place(icon: Icons.location_on_rounded, color: RarColors.danger, text: r.dropoffAddress),
          if (r.service != ServiceType.ride)
            _Place(icon: Icons.inventory_2_rounded, color: RarColors.warning,
                text: '${titleCase(r.packageSize ?? 'package')} package${r.packageNote == null ? '' : ' — ${r.packageNote}'}'),
          const SizedBox(height: RarSpacing.sm),
          Text('${r.passengerName} · ★ ${r.passengerRating.toStringAsFixed(1)} · ${km(r.distanceM)} trip · ${titleCase(r.vehicleClass)} · ${timeAgo(r.requestedAt)}',
              style: onDarkMuted),
          const SizedBox(height: RarSpacing.md),
          if (offer != null)
            Row(children: [
              Expanded(child: Text('Your offer: ${naira(offer!.amount)} — waiting for ${r.passengerName}',
                  style: RarTypography.bodySmall.copyWith(color: RarColors.cyan))),
              TextButton(onPressed: busy ? null : () => onWithdraw(offer!), child: const Text('Withdraw')),
            ])
          else if (r.negotiable)
            RarButton.primary(label: 'Make an offer', leadingIcon: Icons.handshake_rounded, isLoading: busy, onPressed: busy ? null : onOffer)
          else
            RarButton.primary(label: r.service == ServiceType.ride ? 'Accept ride' : 'Accept delivery', leadingIcon: Icons.check_rounded, isLoading: busy, onPressed: busy ? null : onAccept),
        ]),
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: RarSpacing.sm),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: RarTypography.body.copyWith(color: RarColors.white))),
        ]),
      );
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.request});
  final RideRequest request;
  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  static const _step = 10000; // ₦100
  late int _amount = (((widget.request.offeredFare ?? widget.request.estimatedFare) / _step).round() * _step)
      .clamp(_step, 100000000);

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(RarSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your price', style: RarTypography.title.copyWith(color: RarColors.white)),
          const SizedBox(height: 4),
          Text('${r.passengerName} offered ${naira(r.offeredFare)} · estimate ${naira(r.estimatedFare)}', style: onDarkMuted),
          const SizedBox(height: RarSpacing.xl),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(onPressed: _amount > _step ? () => setState(() => _amount -= _step) : null,
                icon: const Icon(Icons.remove_rounded), tooltip: 'Lower by ₦100'),
            const SizedBox(width: RarSpacing.lg),
            Text(naira(_amount), style: RarTypography.display.copyWith(color: RarColors.white, fontSize: 36)),
            const SizedBox(width: RarSpacing.lg),
            IconButton.filledTonal(onPressed: () => setState(() => _amount += _step),
                icon: const Icon(Icons.add_rounded), tooltip: 'Raise by ₦100'),
          ]),
          const SizedBox(height: RarSpacing.xl),
          RarButton.primary(label: 'Send offer of ${naira(_amount)}', onPressed: () => Navigator.pop(context, _amount)),
        ]),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.passenger, required this.busy, required this.onAdvance, required this.onCancel});
  final Trip trip;
  final ({String name, double rating})? passenger;
  final bool busy;
  final ValueChanged<String> onAdvance;
  final ValueChanged<String> onCancel;

  Future<void> _navigate() async {
    final to = trip.status == 'in_progress' ? trip.dropoffAddress : trip.pickupAddress;
    await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${Uri.encodeComponent(to)}'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _askCancel(BuildContext context) async {
    const reasons = ['Passenger not at pickup', 'Passenger asked me to cancel', 'Vehicle problem', 'Safety concern'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RarColors.navy900,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Why are you cancelling?', style: TextStyle(fontWeight: FontWeight.w600))),
        for (final r in reasons) ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
      ])),
    );
    if (reason != null) onCancel(reason);
  }

  @override
  Widget build(BuildContext context) {
    final (String heading, String action, String next) = trip.isDelivery
        ? switch (trip.status) {
            'accepted' => ('Going to collect', "I've arrived", 'driver_arrived'),
            'driver_arrived' => ('Collect the package', 'Package collected', 'in_progress'),
            _ => ('Delivering', 'Delivered', 'completed'),
          }
        : switch (trip.status) {
            'accepted' => ('Heading to pickup', "I've arrived", 'driver_arrived'),
            'driver_arrived' => ('Waiting for passenger', 'Start trip', 'in_progress'),
            _ => ('On trip', 'Complete trip', 'completed'),
          };
    return Panel(
      borderColor: RarColors.cyan.withValues(alpha: 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(heading, style: RarTypography.title.copyWith(color: RarColors.white)),
          const Spacer(),
          Text(naira(trip.fare), style: RarTypography.title.copyWith(color: RarColors.cyan)),
        ]),
        Text('${trip.negotiable ? 'Agreed' : 'Fixed'} fare · ${titleCase(trip.paymentMethod)}', style: onDarkMuted),
        const SizedBox(height: RarSpacing.md),
        Row(children: [
          const CircleAvatar(backgroundColor: RarColors.navy700, child: Icon(Icons.person_rounded, color: RarColors.white)),
          const SizedBox(width: RarSpacing.md),
          Expanded(child: Text(passenger == null ? 'Loading…' : '${trip.isDelivery ? 'Sender: ' : ''}${passenger!.name} · ★ ${passenger!.rating.toStringAsFixed(1)}',
              style: RarTypography.titleSmall.copyWith(color: RarColors.white))),
        ]),
        const SizedBox(height: RarSpacing.md),
        // Only while matched for this pickup or on the trip; hidden afterwards.
        RideContactButtons(
          rideId: trip.id,
          live: const {'accepted', 'driver_arrived', 'in_progress'}.contains(trip.status),
          peerLabel: trip.isDelivery ? 'The sender' : 'Your rider',
          peerName: passenger?.name,
          dark: true,
        ),
        const SizedBox(height: RarSpacing.md),
        _Place(icon: Icons.trip_origin_rounded, color: RarColors.cyan, text: trip.pickupAddress),
        _Place(icon: Icons.location_on_rounded, color: RarColors.danger, text: trip.dropoffAddress),
        if (trip.isDelivery) ...[
          const SizedBox(height: RarSpacing.sm),
          _Place(icon: Icons.inventory_2_rounded, color: RarColors.warning,
              text: '${titleCase(trip.packageSize ?? 'package')} package${trip.packageNote == null ? '' : ' — ${trip.packageNote}'}'),
          Row(children: [
            Expanded(child: _Place(icon: Icons.person_pin_circle_rounded, color: RarColors.cyan,
                text: 'Deliver to ${trip.recipientName ?? 'recipient'}${trip.recipientPhone == null ? '' : ' · ${trip.recipientPhone}'}')),
            if (trip.recipientPhone != null)
              IconButton(
                key: const ValueKey('call-recipient'),
                tooltip: 'Call ${trip.recipientName ?? 'the recipient'}',
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: trip.recipientPhone)),
                icon: const Icon(Icons.call_rounded, color: RarColors.success),
              ),
          ]),
        ],
        const SizedBox(height: RarSpacing.lg),
        RarButton.glass(label: trip.status == 'in_progress' ? 'Navigate to drop-off' : 'Navigate to pickup',
            leadingIcon: Icons.navigation_rounded, onPressed: _navigate),
        const SizedBox(height: RarSpacing.sm),
        RarButton.primary(key: const ValueKey('advance-trip'), label: action, isLoading: busy, onPressed: busy ? null : () => onAdvance(next)),
        if (trip.status != 'in_progress')
          Center(child: TextButton(onPressed: busy ? null : () => _askCancel(context),
              child: const Text('Cancel trip', style: TextStyle(color: RarColors.danger)))),
      ]),
    );
  }
}

class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.name, required this.fare});
  final String name;
  final int fare;
  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  int _stars = 5;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RarColors.navy900,
      title: Text('Trip complete · ${naira(widget.fare)}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('How was ${widget.name}?'),
        const SizedBox(height: RarSpacing.md),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(onPressed: () => setState(() => _stars = i), tooltip: '$i stars',
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: RarColors.warning, size: 34)),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
        FilledButton(onPressed: () => Navigator.pop(context, _stars), child: const Text('Submit')),
      ],
    );
  }
}
