import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../map/map_data.dart' show formatNaira;
import '../rides/ride_models.dart';
import 'wallet_repository.dart';

/// Whether the wallet can pay [fareNaira]; false on demo data or while loading.
bool walletCovers(WidgetRef ref, int fareNaira) {
  final kobo = ref.watch(walletBalanceProvider).value;
  return kobo != null && kobo >= fareNaira * 100;
}

/// The payment method to send: the chosen one, or cash when the wallet
/// can't cover the fare (e.g. after the passenger raised their offer).
PaymentChoice effectivePayment(WidgetRef ref, PaymentChoice chosen, int fareNaira) =>
    chosen == PaymentChoice.wallet && !walletCovers(ref, fareNaira) ? PaymentChoice.cash : chosen;

/// Cash or Wallet, with the wallet balance and why Wallet is unavailable.
class PaymentPicker extends ConsumerWidget {
  const PaymentPicker({super.key, required this.value, required this.fareNaira, required this.onChanged});

  final PaymentChoice value;
  final int fareNaira;
  final ValueChanged<PaymentChoice> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kobo = ref.watch(walletBalanceProvider).value;
    final covers = walletCovers(ref, fareNaira);
    final selected = effectivePayment(ref, value, fareNaira);
    final hint = kobo == null
        ? null
        : covers
            ? null
            : 'Wallet ${formatNaira(kobo / 100)}. Add money in the Wallet tab to pay this trip from it.';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Wraps onto two lines on narrow phones instead of overflowing.
      Wrap(spacing: RarSpacing.sm, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Pay with', style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
        ChoiceChip(
          key: const ValueKey('pay-cash'),
          avatar: const Icon(Icons.payments_rounded, size: 18),
          label: const Text('Cash'),
          selected: selected == PaymentChoice.cash,
          onSelected: (_) => onChanged(PaymentChoice.cash),
        ),
        ChoiceChip(
          key: const ValueKey('pay-wallet'),
          avatar: const Icon(Icons.account_balance_wallet_rounded, size: 18),
          label: Text(kobo == null ? 'Wallet' : 'Wallet · ${formatNaira(kobo / 100)}'),
          selected: selected == PaymentChoice.wallet,
          onSelected: covers ? (_) => onChanged(PaymentChoice.wallet) : null,
        ),
      ]),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(hint, style: RarTypography.caption.copyWith(color: RarColors.textMuted)),
        ),
    ]);
  }
}
