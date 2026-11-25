import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/validation/validators.dart';
import '../home/presentation/controllers/home_providers.dart';
import '../map/map_data.dart';
import 'ride_models.dart';
import 'ride_status_screen.dart';

/// Send a package: choose bike / car / van and the size, say who receives
/// it, then request. Fixed fare, paid in cash.
Future<void> showDeliveryOptions(BuildContext context,
    {required Place pickup, required Place dropoff, required TripEstimate estimate}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RarColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => DeliverySheet(pickup: pickup, dropoff: dropoff, estimate: estimate),
  );
}

class DeliverySheet extends ConsumerStatefulWidget {
  const DeliverySheet({super.key, required this.pickup, required this.dropoff, required this.estimate});
  final Place pickup;
  final Place dropoff;
  final TripEstimate estimate;

  @override
  ConsumerState<DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends ConsumerState<DeliverySheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  DeliveryOption _option = DeliveryOption.dispatchBike;
  PackageSize _size = PackageSize.small;
  bool _busy = false;
  String? _error;

  int get _fare => _option.fareNaira(widget.estimate, _size);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _pickSize(PackageSize s) => setState(() {
        _size = s;
        // A bike can't take a large package; move to a car.
        if (!_option.carries(s)) _option = DeliveryOption.deliveryCar;
      });

  Future<void> _request() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final id = await ref.read(ridesRepositoryProvider).requestDelivery(
            pickup: widget.pickup,
            dropoff: widget.dropoff,
            option: _option,
            size: _size,
            estimate: widget.estimate,
            fareKobo: _fare * 100,
            recipientName: _name.text.trim(),
            recipientPhone: Validators.normaliseNigerianPhone(_phone.text)!,
            note: _note.text,
          );
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute<void>(builder: (_) => RideStatusScreen(rideId: id)));
    } on PostgrestException catch (e) {
      setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      setState(() { _busy = false; _error = 'Could not send the request. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RarTheme.light(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            child: Form(
              key: _form,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(RarSpacing.lg, RarSpacing.md, RarSpacing.lg, RarSpacing.lg),
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: RarColors.outlineLight, borderRadius: RarRadius.pillShape))),
                  const SizedBox(height: RarSpacing.md),
                  Text('Send a package', style: RarTypography.title.copyWith(color: RarColors.navy)),
                  Text('To ${widget.dropoff.name} · ${widget.estimate.distanceKm.toStringAsFixed(1)} km',
                      style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
                  const SizedBox(height: RarSpacing.md),
                  Text('Package size', style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                  const SizedBox(height: RarSpacing.xs),
                  Wrap(spacing: RarSpacing.sm, runSpacing: RarSpacing.sm, children: [
                    for (final s in PackageSize.values)
                      ChoiceChip(
                        key: ValueKey('size-${s.db}'),
                        label: Text(s.label),
                        selected: s == _size,
                        onSelected: (_) => _pickSize(s),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(_size.hint, style: RarTypography.caption.copyWith(color: RarColors.textSecondary)),
                  const SizedBox(height: RarSpacing.md),
                  for (final o in DeliveryOption.values)
                    _DeliveryTile(
                      option: o,
                      fare: o.fareNaira(widget.estimate, _size),
                      selected: o == _option,
                      enabled: o.carries(_size),
                      onTap: () => setState(() => _option = o),
                    ),
                  const SizedBox(height: RarSpacing.sm),
                  Text('Who receives it?', style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                  const SizedBox(height: RarSpacing.sm),
                  RarTextField(
                    key: const ValueKey('recipient-name'),
                    label: "Recipient's name",
                    controller: _name,
                    prefixIcon: Icons.person_rounded,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    validator: (v) => (v ?? '').trim().length < 2 ? "Enter the recipient's name" : null,
                  ),
                  const SizedBox(height: RarSpacing.sm),
                  RarTextField(
                    key: const ValueKey('recipient-phone'),
                    label: "Recipient's phone",
                    hint: '0803 123 4567',
                    controller: _phone,
                    prefixIcon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => Validators.normaliseNigerianPhone(v ?? '') == null
                        ? 'Enter a Nigerian mobile number, e.g. 0803 123 4567.'
                        : null,
                  ),
                  const SizedBox(height: RarSpacing.sm),
                  RarTextField(
                    key: const ValueKey('package-note'),
                    label: 'What is it? (optional)',
                    hint: 'e.g. Documents in a brown envelope',
                    controller: _note,
                    prefixIcon: Icons.inventory_2_rounded,
                    inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  ),
                  const SizedBox(height: RarSpacing.sm),
                  Text("Only the ${_option.service == 'dispatch' ? 'rider' : 'driver'} who takes the job sees the recipient's phone.",
                      style: RarTypography.caption.copyWith(color: RarColors.textMuted)),
                  const SizedBox(height: RarSpacing.sm),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.payments_rounded, size: 16, color: RarColors.success),
                    const SizedBox(width: 6),
                    Text('Cash at pickup', style: RarTypography.bodySmall.copyWith(color: RarColors.navy, fontWeight: FontWeight.w600)),
                    Text(' · fixed price', style: RarTypography.caption.copyWith(color: RarColors.textMuted)),
                  ]),
                  if (_error != null) ...[
                    const SizedBox(height: RarSpacing.sm),
                    RarInlineMessage.error(_error!),
                  ],
                  const SizedBox(height: RarSpacing.md),
                  RarButton.primary(
                    key: const ValueKey('request-delivery'),
                    label: 'Request ${_option.label} · ${formatNaira(_fare)}',
                    isLoading: _busy,
                    onPressed: _busy ? null : _request,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.option, required this.fare, required this.selected,
      required this.enabled, required this.onTap});
  final DeliveryOption option;
  final int fare;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RarSpacing.sm),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: selected ? RarColors.surfaceLight : RarColors.white,
          borderRadius: RarRadius.card,
          child: InkWell(
            key: ValueKey('delivery-${option.name}'),
            borderRadius: RarRadius.card,
            onTap: enabled ? onTap : null,
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
                  Text(option.label, style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                  Text(enabled ? option.blurb : 'Too small for a large package',
                      style: RarTypography.caption.copyWith(color: RarColors.textSecondary)),
                ])),
                Text(formatNaira(fare), style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
