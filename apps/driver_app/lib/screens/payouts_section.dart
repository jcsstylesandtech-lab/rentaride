import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../core/format.dart';
import '../data/payouts_repository.dart';
import '../widgets/common.dart';

/// Wallet balance, commission owed, bank account and withdrawals.
class PayoutsSection extends ConsumerWidget {
  const PayoutsSection({super.key});

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editAccount(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<PayoutAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RarColors.navy900,
      builder: (_) => const BankAccountSheet(),
    );
    if (saved == null || !context.mounted) return;
    ref.invalidate(payoutAccountProvider);
    _toast(context, 'Payouts will go to ${saved.accountName}, ${saved.bankName}.');
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, int balance, int minimum, PayoutAccount account) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RarColors.navy900,
      builder: (_) => WithdrawSheet(balanceKobo: balance, minimumKobo: minimum, account: account),
    );
    if (ok == true && context.mounted) {
      _toast(context, 'Withdrawal requested. We review it and send it to your bank.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(driverWalletProvider);
    final account = ref.watch(payoutAccountProvider);
    final minimum = ref.watch(minWithdrawalProvider).value ?? 100000;
    final withdrawals = ref.watch(withdrawalsProvider).value ?? const <Withdrawal>[];
    final w = wallet.value;
    final acct = account.value;
    final canWithdraw = w != null && acct != null && w.balanceKobo >= minimum;

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Wallet', style: onDarkMuted),
        Semantics(
          liveRegion: true,
          child: Text(
            w == null ? '…' : naira(w.balanceKobo),
            key: const ValueKey('driver-wallet-balance'),
            style: RarTypography.headlineLarge.copyWith(
                color: RarColors.white, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        Text('Wallet-paid trips land here after the 15% platform commission.',
            style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
        if (w != null && w.commissionDueKobo > 0) ...[
          const SizedBox(height: RarSpacing.sm),
          Container(
            key: const ValueKey('commission-due'),
            padding: const EdgeInsets.all(RarSpacing.md),
            decoration: BoxDecoration(
              color: RarColors.warning.withValues(alpha: 0.12),
              borderRadius: RarRadius.card,
              border: Border.all(color: RarColors.warning.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Commission owed from cash trips: ${naira(w.commissionDueKobo)}. '
              "It's taken from your next wallet earnings.",
              style: RarTypography.bodySmall.copyWith(color: RarColors.white),
            ),
          ),
        ],
        const Divider(height: RarSpacing.xxl),
        Row(children: [
          const Icon(Icons.account_balance_rounded, color: RarColors.cyan),
          const SizedBox(width: RarSpacing.md),
          Expanded(
            child: account.isLoading && !account.hasValue
                ? Text('Loading bank account…', style: onDarkMuted)
                : acct == null
                    ? Text('Add the bank account your earnings go to.', style: onDarkMuted)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(acct.accountName,
                            style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
                        Text('${acct.bankName} · ${acct.masked}', style: onDarkMuted),
                      ]),
          ),
          TextButton(
            key: const ValueKey('payout-account-edit'),
            onPressed: () => _editAccount(context, ref),
            child: Text(acct == null ? 'Add' : 'Change'),
          ),
        ]),
        const SizedBox(height: RarSpacing.md),
        RarButton.primary(
          key: const ValueKey('withdraw'),
          label: 'Withdraw',
          leadingIcon: Icons.north_east_rounded,
          onPressed: canWithdraw ? () => _withdraw(context, ref, w.balanceKobo, minimum, acct) : null,
        ),
        if (!canWithdraw && w != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              acct == null
                  ? 'Add a bank account to withdraw.'
                  : 'You can withdraw once your balance reaches ${naira(minimum)}.',
              textAlign: TextAlign.center,
              style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted),
            ),
          ),
        if (withdrawals.isNotEmpty) ...[
          const SizedBox(height: RarSpacing.lg),
          Text('Withdrawals', style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
          for (final x in withdrawals.take(5)) _WithdrawalRow(x),
        ],
      ]),
    );
  }
}

class _WithdrawalRow extends StatelessWidget {
  const _WithdrawalRow(this.w);
  final Withdrawal w;

  @override
  Widget build(BuildContext context) {
    final color = switch (w.status) {
      'paid' => RarColors.success,
      'failed' || 'rejected' => RarColors.danger,
      _ => RarColors.cyan,
    };
    return Padding(
      padding: const EdgeInsets.only(top: RarSpacing.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(naira(w.amountKobo), style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
            Text('${timeAgo(w.createdAt.toLocal())} · ${w.bankName}', style: onDarkMuted),
            if (w.failureReason != null && (w.status == 'failed' || w.status == 'rejected'))
              Text(w.failureReason!, style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: RarRadius.pillShape),
          child: Text(w.statusLabel, style: RarTypography.caption.copyWith(color: color)),
        ),
      ]),
    );
  }
}

/// Choose a bank, enter the account number; the server confirms the
/// account name with the bank before saving. Pops with the saved account.
class BankAccountSheet extends ConsumerStatefulWidget {
  const BankAccountSheet({super.key});

  @override
  ConsumerState<BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends ConsumerState<BankAccountSheet> {
  final _number = TextEditingController();
  List<Bank>? _banks;
  Bank? _bank;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _error = null);
    try {
      final banks = await ref.read(payoutsRepositoryProvider).banks();
      if (mounted) setState(() => _banks = banks);
    } on PayoutFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    if (_bank == null) return setState(() => _error = 'Choose your bank.');
    if (!RegExp(r'^\d{10}$').hasMatch(_number.text)) {
      return setState(() => _error = 'Enter your 10-digit account number.');
    }
    setState(() { _busy = true; _error = null; });
    try {
      final saved = await ref
          .read(payoutsRepositoryProvider)
          .savePayoutAccount(bankCode: _bank!.code, accountNumber: _number.text);
      if (mounted) Navigator.of(context).pop(saved);
    } on PayoutFailure catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = _banks;
    return Theme(
      data: RarTheme.dark(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(RarSpacing.lg, RarSpacing.lg, RarSpacing.lg,
              RarSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Bank account', style: RarTypography.title.copyWith(color: RarColors.white)),
            Text('Earnings are paid to an account in your name. We check the name with your bank.',
                style: onDarkMuted),
            const SizedBox(height: RarSpacing.lg),
            if (banks == null && _error == null)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: RarColors.cyan)))
            else if (banks != null)
              DropdownMenu<Bank>(
                key: const ValueKey('bank-picker'),
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                requestFocusOnTap: true,
                label: const Text('Bank'),
                menuHeight: 320,
                onSelected: _busy ? null : (b) => setState(() { _bank = b; _error = null; }),
                dropdownMenuEntries: [for (final b in banks) DropdownMenuEntry(value: b, label: b.name)],
              ),
            const SizedBox(height: RarSpacing.md),
            RarTextField(
              key: const ValueKey('account-number'),
              label: 'Account number',
              controller: _number,
              prefixIcon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
              enabled: !_busy,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: RarSpacing.md),
              RarInlineMessage.error(
                _error!,
                action: banks == null
                    ? TextButton(onPressed: _loadBanks, child: const Text('Try again'))
                    : null,
              ),
            ],
            const SizedBox(height: RarSpacing.lg),
            RarButton.primary(
              key: const ValueKey('bank-save'),
              label: 'Check and save',
              isLoading: _busy,
              onPressed: banks == null ? null : _save,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Amount to withdraw (up to the balance). Pops with true when requested.
class WithdrawSheet extends ConsumerStatefulWidget {
  const WithdrawSheet({super.key, required this.balanceKobo, required this.minimumKobo, required this.account});
  final int balanceKobo;
  final int minimumKobo;
  final PayoutAccount account;

  @override
  ConsumerState<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<WithdrawSheet> {
  late final _amount = TextEditingController(text: '${widget.balanceKobo ~/ 100}');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountNaira = int.tryParse(_amount.text);
    if (amountNaira == null || amountNaira <= 0) return setState(() => _error = 'Enter an amount.');
    final kobo = amountNaira * 100;
    if (kobo < widget.minimumKobo) {
      return setState(() => _error = 'The minimum withdrawal is ${naira(widget.minimumKobo)}.');
    }
    if (kobo > widget.balanceKobo) return setState(() => _error = "You can't withdraw more than your balance.");
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(payoutsRepositoryProvider).requestWithdrawal(kobo);
      if (mounted) Navigator.of(context).pop(true);
    } on PayoutFailure catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RarTheme.dark(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(RarSpacing.lg, RarSpacing.lg, RarSpacing.lg,
              RarSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Withdraw', style: RarTypography.title.copyWith(color: RarColors.white)),
            Text('To ${widget.account.accountName} · ${widget.account.bankName} ${widget.account.masked}', style: onDarkMuted),
            const SizedBox(height: RarSpacing.lg),
            RarTextField(
              key: const ValueKey('withdraw-amount'),
              label: 'Amount (₦) · balance ${naira(widget.balanceKobo)}',
              controller: _amount,
              prefixIcon: Icons.payments_rounded,
              keyboardType: TextInputType.number,
              enabled: !_busy,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: RarSpacing.md),
              RarInlineMessage.error(_error!),
            ],
            const SizedBox(height: RarSpacing.sm),
            Text('The amount leaves your wallet now. If the withdrawal is rejected or the transfer fails, it comes back.',
                style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
            const SizedBox(height: RarSpacing.lg),
            RarButton.primary(
              key: const ValueKey('withdraw-submit'),
              label: 'Request withdrawal',
              isLoading: _busy,
              onPressed: _submit,
            ),
          ]),
        ),
      ),
    );
  }
}
