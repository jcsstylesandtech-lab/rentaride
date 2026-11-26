import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/presentation/widgets/account_tabs.dart' show TabPage;
import '../map/map_data.dart' show formatNaira;
import 'wallet_repository.dart';

String _koboToNaira(int kobo) => formatNaira(kobo / 100);

/// Opens the Paystack checkout outside the app (replaceable in tests).
final checkoutLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// Balance, Add money (Paystack) and wallet history.
class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key});

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> with WidgetsBindingObserver {
  /// A top-up opened in Paystack that we haven't confirmed yet.
  String? _pendingReference;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the Paystack checkout: confirm the payment.
    if (state == AppLifecycleState.resumed && _pendingReference != null) _check();
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addMoney() async {
    final repo = ref.read(walletRepositoryProvider);
    if (repo == null) return;
    final checkout = await showModalBottomSheet<TopUpCheckout>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RarColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => TopUpSheet(repository: repo),
    );
    if (checkout == null || !mounted) return;
    setState(() => _pendingReference = checkout.reference);
    final opened = await ref.read(checkoutLauncherProvider)(checkout.url);
    if (!opened && mounted) _toast("Couldn't open Paystack. Try again.");
  }

  Future<void> _check() async {
    final reference = _pendingReference;
    final repo = ref.read(walletRepositoryProvider);
    if (reference == null || repo == null || _checking) return;
    setState(() => _checking = true);
    try {
      final status = await repo.verify(reference);
      if (!mounted) return;
      switch (status) {
        case 'succeeded':
          setState(() => _pendingReference = null);
          _toast('Money added to your wallet.');
        case 'failed':
          setState(() => _pendingReference = null);
          _toast('That payment did not go through. You were not charged.');
        default:
          _toast("Paystack hasn't confirmed the payment yet. Check again in a moment.");
      }
    } on WalletFailure catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(walletRepositoryProvider) == null;
    final balance = ref.watch(walletBalanceProvider);
    final history = ref.watch(walletHistoryProvider);

    return TabPage(
      title: 'Wallet',
      children: [
        _BalanceCard(
          balance: balance,
          demo: demo,
          onAddMoney: demo ? null : _addMoney,
        ),
        if (_pendingReference != null) ...[
          const SizedBox(height: RarSpacing.md),
          RarInlineMessage.info(
            'Finish paying in Paystack, then come back here. We add the money as soon as Paystack confirms it.',
            action: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('wallet-check-payment'),
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Check payment'),
              ),
            ),
          ),
        ],
        const SizedBox(height: RarSpacing.xl),
        Text('History', style: RarTypography.title.copyWith(color: RarColors.navy)),
        const SizedBox(height: RarSpacing.sm),
        RarSkeletonSwitcher(
          isLoading: history.isLoading && !history.hasValue,
          skeleton: const SkeletonList(itemCount: 3),
          child: switch (history) {
            AsyncError() => TextButton.icon(
                onPressed: () => ref.invalidate(walletHistoryProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Couldn't load your history. Try again"),
              ),
            AsyncValue(:final value) when (value ?? const []).isEmpty => Padding(
                padding: const EdgeInsets.symmetric(vertical: RarSpacing.lg),
                child: Text(
                  demo
                      ? 'Your wallet works once the app is connected to the Rent A Ride server.'
                      : 'Money you add and trips you pay from your wallet show up here.',
                  style: RarTypography.body.copyWith(color: RarColors.textSecondary),
                ),
              ),
            AsyncValue(:final value) => Column(
                children: [for (final e in value ?? const <WalletEntry>[]) _EntryTile(entry: e)],
              ),
          },
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.demo, required this.onAddMoney});
  final AsyncValue<int?> balance;
  final bool demo;
  final VoidCallback? onAddMoney;

  @override
  Widget build(BuildContext context) {
    final kobo = balance.value;
    return Container(
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
          Text('Available balance',
              style: RarTypography.bodySmall.copyWith(color: RarColors.textOnDarkSecondary)),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              kobo == null ? (demo ? '₦0' : '…') : _koboToNaira(kobo),
              key: const ValueKey('wallet-balance'),
              style: RarTypography.headlineLarge.copyWith(
                color: RarColors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: RarSpacing.sm),
          Text(
            demo
                ? 'Demo mode: connect the app to the server to add money.'
                : 'Pay for trips from your wallet. Add money by card, bank transfer or USSD with Paystack.',
            style: RarTypography.bodySmall.copyWith(color: RarColors.textOnDarkSecondary),
          ),
          const SizedBox(height: RarSpacing.lg),
          RarButton.primary(
            key: const ValueKey('wallet-add-money'),
            label: 'Add money',
            leadingIcon: Icons.add_rounded,
            onPressed: onAddMoney,
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final credit = entry.amountKobo > 0;
    final d = entry.createdAt.toLocal();
    final when = '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (credit ? RarColors.success : RarColors.royal).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: credit ? RarColors.success : RarColors.royal, size: 20),
        ),
        const SizedBox(width: RarSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title, style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
            Text(when, style: RarTypography.caption.copyWith(color: RarColors.textMuted)),
          ]),
        ),
        Text(
          '${credit ? '+' : '−'}${_koboToNaira(entry.amountKobo.abs())}',
          style: RarTypography.titleSmall.copyWith(
            color: credit ? RarColors.success : RarColors.navy,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ]),
    );
  }
}

/// Choose an amount and start a Paystack checkout. Pops with the checkout.
class TopUpSheet extends StatefulWidget {
  const TopUpSheet({super.key, required this.repository});
  final WalletRepository repository;

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  static const _presets = [1000, 2000, 5000, 10000];
  final _amount = TextEditingController(text: '2000');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _naira => int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));

  String? _validate() {
    final n = _naira;
    if (n == null || n == 0) return 'Enter an amount.';
    if (n * 100 < WalletLimits.minTopUpKobo) return 'The minimum is ${_nairaLabel(WalletLimits.minTopUpKobo)}.';
    if (n * 100 > WalletLimits.maxTopUpKobo) return 'The maximum is ${_nairaLabel(WalletLimits.maxTopUpKobo)}.';
    return null;
  }

  static String _nairaLabel(int kobo) => _koboToNaira(kobo);

  Future<void> _continue() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final checkout = await widget.repository.startTopUp(_naira! * 100);
      if (mounted) Navigator.of(context).pop(checkout);
    } on WalletFailure catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _naira;
    return Theme(
      data: RarTheme.light(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(RarSpacing.lg, RarSpacing.md, RarSpacing.lg,
              RarSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: RarColors.outlineLight, borderRadius: RarRadius.pillShape))),
            const SizedBox(height: RarSpacing.md),
            Text('Add money', style: RarTypography.title.copyWith(color: RarColors.navy)),
            Text('Pay securely with Paystack: card, bank transfer or USSD.',
                style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
            const SizedBox(height: RarSpacing.lg),
            Wrap(spacing: RarSpacing.sm, runSpacing: RarSpacing.sm, children: [
              for (final p in _presets)
                ChoiceChip(
                  key: ValueKey('topup-preset-$p'),
                  label: Text(formatNaira(p)),
                  selected: n == p,
                  onSelected: _busy ? null : (_) => setState(() { _amount.text = '$p'; _error = null; }),
                ),
            ]),
            const SizedBox(height: RarSpacing.lg),
            RarTextField(
              key: const ValueKey('topup-amount'),
              label: 'Amount (₦)',
              controller: _amount,
              prefixIcon: Icons.payments_rounded,
              keyboardType: TextInputType.number,
              enabled: !_busy,
              onChanged: (_) => setState(() => _error = null),
              onFieldSubmitted: (_) => _continue(),
            ),
            if (_error != null) ...[
              const SizedBox(height: RarSpacing.md),
              RarInlineMessage.error(_error!),
            ],
            const SizedBox(height: RarSpacing.lg),
            RarButton.primary(
              key: const ValueKey('topup-continue'),
              label: n == null || n == 0 ? 'Continue to Paystack' : 'Pay ${formatNaira(n)} with Paystack',
              trailingIcon: Icons.open_in_new_rounded,
              isLoading: _busy,
              onPressed: _continue,
            ),
          ]),
        ),
      ),
    );
  }
}
