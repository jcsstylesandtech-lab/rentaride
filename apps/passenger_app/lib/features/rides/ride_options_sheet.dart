import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../home/presentation/controllers/home_providers.dart';
import '../map/map_data.dart';
import 'ride_models.dart';
import 'ride_status_screen.dart';

/// Choose a ride type and how to pay the fare, then request the ride.
Future<void> showRideOptions(BuildContext context, {required Place pickup, required Place dropoff, required TripEstimate estimate}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RarColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => RideOptionsSheet(pickup: pickup, dropoff: dropoff, estimate: estimate),
  );
}

class RideOptionsSheet extends ConsumerStatefulWidget {
  const RideOptionsSheet({super.key, required this.pickup, required this.dropoff, required this.estimate});
  final Place pickup;
  final Place dropoff;
  final TripEstimate estimate;

  @override
  ConsumerState<RideOptionsSheet> createState() => _RideOptionsSheetState();
}

class _RideOptionsSheetState extends ConsumerState<RideOptionsSheet> {
  RideOption _option = RideOption.economy;
  bool _negotiate = false;
  int? _offerNaira;
  bool _busy = false;
  String? _error;

  int get _fixed => _option.fareNaira(widget.estimate);
  int get _minOffer => ((_fixed * 0.6) / 50).round() * 50;
  int get _offer => (_offerNaira ?? _fixed).clamp(_minOffer, _fixed * 3);

  Future<void> _request() async {
    setState(() { _busy = true; _error = null; });
    try {
      final id = await ref.read(ridesRepositoryProvider).requestRide(
            pickup: widget.pickup,
            dropoff: widget.dropoff,
            option: _option,
            estimate: widget.estimate,
            estimatedKobo: _fixed * 100,
            offeredKobo: _negotiate ? _offer * 100 : null,
          );
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute<void>(builder: (_) => RideStatusScreen(rideId: id)));
    } on PostgrestException catch (e) {
      setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      setState(() { _busy = false; _error = 'Could not request the ride. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RarTheme.light(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(RarSpacing.lg, RarSpacing.md, RarSpacing.lg,
              RarSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: RarColors.outlineLight, borderRadius: RarRadius.pillShape))),
            const SizedBox(height: RarSpacing.md),
            Text('Choose a ride', style: RarTypography.title.copyWith(color: RarColors.navy)),
            Text('To ${widget.dropoff.name} · ${widget.estimate.distanceKm.toStringAsFixed(1)} km · ~${widget.estimate.durationMin} min',
                style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
            const SizedBox(height: RarSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.32),
              child: ListView(shrinkWrap: true, children: [
                for (final o in RideOption.values)
                  _OptionTile(option: o, fare: o.fareNaira(widget.estimate), selected: o == _option,
                      onTap: () => setState(() { _option = o; _offerNaira = null; })),
              ]),
            ),
            const SizedBox(height: RarSpacing.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Fixed fare'), icon: Icon(Icons.lock_rounded)),
                ButtonSegment(value: true, label: Text('Offer your price'), icon: Icon(Icons.handshake_rounded)),
              ],
              selected: {_negotiate},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _negotiate = s.first),
            ),
            const SizedBox(height: RarSpacing.sm),
            if (_negotiate)
              Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Lower by ₦100',
                  onPressed: _offer - 100 >= _minOffer ? () => setState(() => _offerNaira = _offer - 100) : null,
                  icon: const Icon(Icons.remove_rounded)),
                Expanded(child: Column(children: [
                  Text(formatNaira(_offer), style: RarTypography.headline.copyWith(color: RarColors.navy)),
                  Text('Drivers can accept or counter. Suggested ${formatNaira(_fixed)}',
                      textAlign: TextAlign.center, style: RarTypography.caption.copyWith(color: RarColors.textSecondary)),
                ])),
                IconButton.filledTonal(
                  tooltip: 'Raise by ₦100',
                  onPressed: () => setState(() => _offerNaira = _offer + 100),
                  icon: const Icon(Icons.add_rounded)),
              ])
            else
              Text('You pay ${formatNaira(_fixed)} — the price is locked before you ride.',
                  textAlign: TextAlign.center, style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
            const SizedBox(height: RarSpacing.sm),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.payments_rounded, size: 16, color: RarColors.success),
              const SizedBox(width: 6),
              Text('Cash', style: RarTypography.bodySmall.copyWith(color: RarColors.navy, fontWeight: FontWeight.w600)),
              Text(' · cards and wallet coming soon', style: RarTypography.caption.copyWith(color: RarColors.textMuted)),
            ]),
            if (_error != null) ...[
              const SizedBox(height: RarSpacing.sm),
              RarInlineMessage.error(_error!),
            ],
            const SizedBox(height: RarSpacing.md),
            RarButton.primary(
              key: const ValueKey('request-ride'),
              label: _negotiate ? 'Request · offer ${formatNaira(_offer)}' : 'Request ${_option.label} · ${formatNaira(_fixed)}',
              isLoading: _busy,
              onPressed: _busy ? null : _request,
            ),
          ]),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.fare, required this.selected, required this.onTap});
  final RideOption option;
  final int fare;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RarSpacing.sm),
      child: Material(
        color: selected ? RarColors.surfaceLight : RarColors.white,
        borderRadius: RarRadius.card,
        child: InkWell(
          borderRadius: RarRadius.card,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(RarSpacing.md),
            decoration: BoxDecoration(
              borderRadius: RarRadius.card,
              border: Border.all(color: selected ? RarColors.royal : RarColors.outlineLight, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Icon(option.icon, color: RarColors.royal, size: 30),
              const SizedBox(width: RarSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${option.label} · ${option.seats} seat${option.seats == 1 ? '' : 's'}',
                    style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                Text(option.blurb, style: RarTypography.caption.copyWith(color: RarColors.textSecondary)),
              ])),
              Text(formatNaira(fare), style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
            ]),
          ),
        ),
      ),
    );
  }
}
