import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  RealtimeChannel? _channel;
  DocumentType? _uploading;

  @override
  void initState() {
    super.initState();
    // Approval / document review in the admin dashboard updates this screen live.
    _channel = ref.read(repoProvider).watchMine(() {
      if (mounted) ref.invalidate(driverStateProvider);
    });
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) ref.read(repoProvider).unwatch(c);
    super.dispose();
  }

  void _refresh() => ref.invalidate(driverStateProvider);

  Future<void> _editLicence(DriverState s) async {
    final ctrl = TextEditingController(text: s.driver?.licenceNumber ?? '');
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RarColors.navy900,
      builder: (ctx) => _Sheet(
        title: "Driver's licence",
        children: [
          RarTextField(label: 'Licence number', controller: ctrl, prefixIcon: Icons.badge_rounded,
              autofocus: true, textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(40)]),
          const SizedBox(height: RarSpacing.lg),
          RarButton.primary(label: 'Save', onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase())),
        ],
      ),
    );
    if (value == null || value.length < 5) {
      if (value != null && mounted) showSnack(context, 'Enter your full licence number', error: true);
      return;
    }
    try {
      final repo = ref.read(repoProvider);
      s.driver == null ? await repo.register(value) : await repo.updateLicence(value);
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _chooseService(DriverState s) async {
    final current = s.driver?.serviceType;
    final picked = await showModalBottomSheet<ServiceType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RarColors.navy900,
      builder: (ctx) => _Sheet(
        title: 'What will you do?',
        children: [
          for (final t in ServiceType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: RarSpacing.sm),
              child: InkWell(
                key: ValueKey('service-${t.name}'),
                borderRadius: RarRadius.card,
                onTap: () => Navigator.pop(ctx, t),
                child: Panel(
                borderColor: t == current ? RarColors.cyan : null,
                child: Row(children: [
                  Icon(_serviceIcon(t), color: RarColors.cyan),
                  const SizedBox(width: RarSpacing.md),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.label, style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
                    Text(t.hint, style: onDarkMuted),
                  ])),
                  if (t == current) const Icon(Icons.check_circle_rounded, color: RarColors.cyan),
                ]),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await ref.read(repoProvider).chooseService(picked, registered: s.driver != null);
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _editVehicle(Vehicle? v) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RarColors.navy900,
      builder: (_) => _VehicleSheet(vehicle: v),
    );
    if (saved == true) _refresh();
  }

  Future<void> _upload(DocumentType type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RarColors.navy900,
      builder: (ctx) => _Sheet(title: type.label, children: [
        ListTile(leading: const Icon(Icons.photo_camera_rounded, color: RarColors.cyan), title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: RarColors.cyan), title: const Text('Choose from photos'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ]),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 80);
      if (file == null) return;
      setState(() => _uploading = type);
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      await ref.read(repoProvider).uploadDocument(type, bytes, ext);
      _refresh();
      if (mounted) showSnack(context, '${type.label} uploaded');
    } on PlatformException catch (e) {
      if (mounted) {
        showSnack(context, e.code.contains('camera') ? 'Camera not available here — choose from photos.' : friendlyError(e), error: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(driverStateProvider).value;
    if (s == null) return const LoadingScreen();
    final docs = s.latestDocs;
    final serviceDone = s.driver != null;
    final licenceDone = s.driver?.licenceNumber?.isNotEmpty == true;
    final vehicleDone = s.vehicles.isNotEmpty;
    final docsDone = s.docsComplete;
    final allDone = licenceDone && vehicleDone && docsDone;

    return DriverScaffold(
      child: RefreshIndicator(
        color: RarColors.cyan,
        onRefresh: () async => _refresh(),
        child: ListView(
          children: [
            const SizedBox(height: RarSpacing.md),
            Row(children: [
              const Expanded(child: Align(alignment: Alignment.centerLeft, child: RarWordmark(logoSize: 34, fontSize: 18, subtitle: 'Driver'))),
              TextButton(onPressed: () => ref.read(repoProvider).signOut(),
                  child: const Text('Sign out', style: TextStyle(color: RarColors.textOnDarkSecondary))),
            ]),
            const SizedBox(height: RarSpacing.lg),
            Text('Hi ${s.profile?.fullName.split(' ').first ?? 'there'} 👋',
                style: RarTypography.headlineLarge.copyWith(color: RarColors.white)),
            const SizedBox(height: RarSpacing.xs),
            Text('Finish these steps so our team can verify you.', style: onDarkMuted),
            const SizedBox(height: RarSpacing.lg),
            _StatusBanner(state: s, allDone: allDone),
            const SizedBox(height: RarSpacing.lg),
            _Step(
              number: 1, done: serviceDone, title: 'What you will do',
              subtitle: serviceDone ? s.driver!.serviceType.label : 'Ride driver, dispatch rider or delivery driver',
              action: s.approved ? null : (serviceDone ? 'Change' : 'Choose'),
              onAction: () => _chooseService(s),
            ),
            _Step(
              number: 2, done: licenceDone, title: "Driver's licence",
              subtitle: licenceDone ? s.driver!.licenceNumber! : 'Add your licence number',
              action: s.approved || !serviceDone ? null : (licenceDone ? 'Edit' : 'Add'),
              onAction: () => _editLicence(s),
              locked: !serviceDone,
            ),
            _Step(
              number: 3, done: vehicleDone, title: 'Your vehicle',
              subtitle: vehicleDone ? s.vehicles.first.title : 'Make, model, colour and plate number',
              trailing: vehicleDone ? StatusChip(s.vehicles.first.review) : null,
              action: !licenceDone ? null : (vehicleDone ? 'Edit' : 'Add'),
              onAction: () => _editVehicle(vehicleDone ? s.vehicles.first : null),
              locked: !licenceDone,
            ),
            _Step(
              number: 4, done: docsDone, title: 'Documents',
              subtitle: 'Clear photos. Our team reviews each one.',
              locked: !licenceDone,
            ),
            if (licenceDone)
              ...DocumentType.values.map((t) {
                final d = docs[t];
                return Padding(
                  padding: const EdgeInsets.only(left: 44, bottom: RarSpacing.sm),
                  child: Panel(
                    padding: const EdgeInsets.symmetric(horizontal: RarSpacing.md, vertical: RarSpacing.sm),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.label + (t.required ? '' : ' (optional)'),
                              style: RarTypography.bodySmall.copyWith(color: RarColors.white, fontWeight: FontWeight.w600)),
                          if (d?.note != null) Text(d!.note!, style: RarTypography.caption.copyWith(color: RarColors.danger)),
                        ]),
                      ),
                      if (d != null) ...[StatusChip(d.review), const SizedBox(width: 6)],
                      if (_uploading == t)
                        const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: RarColors.cyan))
                      else if (d == null || d.review == 'rejected')
                        TextButton(onPressed: _uploading == null ? () => _upload(t) : null,
                            child: Text(d == null ? 'Upload' : 'Re-upload')),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: RarSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.allDone});
  final DriverState state;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final status = state.driver?.status;
    final (IconData icon, Color color, String title, String body) = switch (status) {
      DriverStatus.rejected => (Icons.error_rounded, RarColors.danger, 'Application not approved',
          state.driver?.rejectionReason ?? 'Fix the items marked rejected and re-upload.'),
      DriverStatus.suspended => (Icons.block_rounded, RarColors.danger, 'Account suspended',
          state.driver?.rejectionReason ?? 'Contact Rent A Ride support.'),
      _ when allDone => (Icons.hourglass_top_rounded, RarColors.warning, 'Under review',
          "You're all set. We usually verify drivers within 24 hours — this screen updates by itself when you're approved."),
      _ => (Icons.checklist_rounded, RarColors.cyan, 'Get verified to start driving',
          'Every Rent A Ride driver is checked before their first trip. It keeps riders safe — and you too.'),
    };
    return Panel(
      borderColor: color.withValues(alpha: 0.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: RarSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
          const SizedBox(height: 2),
          Text(body, style: onDarkMuted),
        ])),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.done, required this.title, required this.subtitle,
      this.action, this.onAction, this.trailing, this.locked = false});
  final int number;
  final bool done;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RarSpacing.md),
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? RarColors.success : RarColors.glassFillDarkStrong,
              border: Border.all(color: done ? RarColors.success : RarColors.glassBorderDark),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: RarColors.white)
                : Text('$number', style: RarTypography.label.copyWith(color: RarColors.white)),
          ),
          const SizedBox(width: RarSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
            Text(subtitle, style: onDarkMuted, maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          ?trailing,
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(RarSpacing.lg, RarSpacing.lg, RarSpacing.lg,
          RarSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: RarTypography.title.copyWith(color: RarColors.white)),
          const SizedBox(height: RarSpacing.lg),
          ...children,
        ]),
      ),
    );
  }
}

class _VehicleSheet extends ConsumerStatefulWidget {
  const _VehicleSheet({this.vehicle});
  final Vehicle? vehicle;
  @override
  ConsumerState<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends ConsumerState<_VehicleSheet> {
  final _form = GlobalKey<FormState>();
  late final _make = TextEditingController(text: widget.vehicle?.make);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _colour = TextEditingController(text: widget.vehicle?.colour);
  late final _year = TextEditingController(text: widget.vehicle?.year?.toString());
  late final _plate = TextEditingController(text: widget.vehicle?.plateNumber);
  late VehicleClass _class = widget.vehicle?.vehicleClass ?? VehicleClass.economy;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_make, _model, _colour, _year, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(repoProvider).saveVehicle(
        id: widget.vehicle?.id, vehicleClass: _class,
        make: _make.text.trim(), model: _model.text.trim(), colour: _colour.text.trim(),
        year: int.tryParse(_year.text.trim()), plate: _plate.text.trim(),
        seats: _class == VehicleClass.motorcycle ? 1 : (_class == VehicleClass.suv ? 6 : 4),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyError(e).contains('plate_number') ? 'That plate number is already registered.' : friendlyError(e);
      });
    }
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final maxYear = DateTime.now().year + 1;
    return Form(
      key: _form,
      child: _Sheet(title: 'Your vehicle', children: [
        Wrap(spacing: 8, runSpacing: 8, children: VehicleClass.values.map((c) => ChoiceChip(
              label: Text(titleCase(c.name == 'suv' ? 'SUV' : c.name)),
              selected: _class == c,
              onSelected: (_) => setState(() => _class = c),
              selectedColor: RarColors.royal,
            )).toList()),
        const SizedBox(height: RarSpacing.md),
        Row(children: [
          Expanded(child: RarTextField(label: 'Make', hint: 'Toyota', controller: _make, validator: _required,
              textCapitalization: TextCapitalization.words)),
          const SizedBox(width: RarSpacing.sm),
          Expanded(child: RarTextField(label: 'Model', hint: 'Corolla', controller: _model, validator: _required,
              textCapitalization: TextCapitalization.words)),
        ]),
        const SizedBox(height: RarSpacing.md),
        Row(children: [
          Expanded(child: RarTextField(label: 'Colour', hint: 'Silver', controller: _colour, validator: _required,
              textCapitalization: TextCapitalization.words)),
          const SizedBox(width: RarSpacing.sm),
          Expanded(child: RarTextField(label: 'Year', hint: '2015', controller: _year, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              validator: (v) {
                final y = int.tryParse(v ?? '');
                return y == null || y < 1990 || y > maxYear ? '1990–$maxYear' : null;
              })),
        ]),
        const SizedBox(height: RarSpacing.md),
        RarTextField(label: 'Plate number', hint: 'ABC-123-XY', controller: _plate,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            validator: (v) => (v ?? '').trim().length < 5 ? 'Enter the full plate number' : null),
        if (widget.vehicle?.review == 'approved') ...[
          const SizedBox(height: RarSpacing.sm),
          Text('Changing details sends the vehicle back for review.',
              style: RarTypography.caption.copyWith(color: RarColors.warning)),
        ],
        if (_error != null) ...[
          const SizedBox(height: RarSpacing.sm),
          Text(_error!, style: RarTypography.bodySmall.copyWith(color: RarColors.danger)),
        ],
        const SizedBox(height: RarSpacing.lg),
        RarButton.primary(label: 'Save vehicle', isLoading: _busy, onPressed: _busy ? null : _save),
      ]),
    );
  }
}

IconData _serviceIcon(ServiceType t) => switch (t) {
      ServiceType.ride => Icons.directions_car_rounded,
      ServiceType.dispatch => Icons.two_wheeler_rounded,
      ServiceType.delivery => Icons.local_shipping_rounded,
    };
