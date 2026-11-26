import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_passenger/features/rides/ride_models.dart';
import 'package:rent_a_ride_passenger/features/wallet/payment_picker.dart';
import 'package:rent_a_ride_passenger/features/wallet/wallet_repository.dart';
import 'package:rent_a_ride_passenger/features/wallet/wallet_tab.dart';

class _FakeWallet implements WalletRepository {
  _FakeWallet(int balance) : _balance = StreamController<int>.broadcast() {
    current = balance;
  }

  final StreamController<int> _balance;
  late int current;
  final topUps = <int>[];
  final verified = <String>[];
  String verifyResult = 'succeeded';
  String? failTopUpWith;
  final entries = <WalletEntry>[];

  void credit(int kobo) {
    current += kobo;
    entries.insert(0, WalletEntry(type: 'top_up', amountKobo: kobo, balanceAfterKobo: current, createdAt: DateTime(2026, 11, 26, 9, 5)));
    _balance.add(current);
  }

  @override
  Stream<int> watchBalance() async* {
    yield current;
    yield* _balance.stream;
  }

  @override
  Future<List<WalletEntry>> history() async => List.of(entries);

  @override
  Future<TopUpCheckout> startTopUp(int amountKobo) async {
    if (failTopUpWith != null) throw WalletFailure(failTopUpWith!);
    topUps.add(amountKobo);
    return TopUpCheckout('tu-test', Uri.parse('https://checkout.paystack.com/test'));
  }

  @override
  Future<String> verify(String reference) async {
    verified.add(reference);
    if (verifyResult == 'succeeded') credit(topUps.last);
    return verifyResult;
  }
}

Widget _host(Widget child, _FakeWallet wallet, {List<Uri>? opened}) => ProviderScope(
      overrides: [
        walletRepositoryProvider.overrideWithValue(wallet),
        checkoutLauncherProvider.overrideWithValue((u) async {
          opened?.add(u);
          return true;
        }),
      ],
      child: MaterialApp(theme: RarTheme.light(), home: Scaffold(body: child)),
    );

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('shows the balance and an empty history', (tester) async {
    await tester.pumpWidget(_host(const WalletTab(), _FakeWallet(250000)));
    await tester.pumpAndSettle();
    expect(find.text('₦2,500'), findsOneWidget);
    expect(find.textContaining('Money you add'), findsOneWidget);
  });

  testWidgets('add money: validates, opens Paystack, confirms and updates', (tester) async {
    final wallet = _FakeWallet(0);
    final opened = <Uri>[];
    await tester.pumpWidget(_host(const WalletTab(), wallet, opened: opened));
    await tester.pumpAndSettle();

    await tester.tap(_key('wallet-add-money'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: _key('topup-amount'), matching: find.byType(EditableText)), '100');
    await tester.tap(_key('topup-continue'));
    await tester.pumpAndSettle();
    expect(find.text('The minimum is ₦500.'), findsOneWidget);
    expect(wallet.topUps, isEmpty);

    await tester.tap(_key('topup-preset-5000'));
    await tester.pumpAndSettle();
    expect(find.text('Pay ₦5,000 with Paystack'), findsOneWidget);
    await tester.tap(_key('topup-continue'));
    await tester.pumpAndSettle();
    expect(wallet.topUps, [500000]);
    expect(opened.single.host, 'checkout.paystack.com');
    expect(find.textContaining('Finish paying in Paystack'), findsOneWidget);

    await tester.tap(_key('wallet-check-payment'));
    await tester.pumpAndSettle();
    expect(wallet.verified, ['tu-test']);
    expect(find.text('Money added to your wallet.'), findsOneWidget);
    expect(find.text('₦5,000'), findsOneWidget);
    expect(find.text('Money added'), findsOneWidget); // history row
    expect(find.textContaining('Finish paying in Paystack'), findsNothing);
  });

  testWidgets('pending payment keeps the reminder; server errors are shown', (tester) async {
    final wallet = _FakeWallet(0)..verifyResult = 'pending';
    await tester.pumpWidget(_host(const WalletTab(), wallet));
    await tester.pumpAndSettle();
    await tester.tap(_key('wallet-add-money'));
    await tester.pumpAndSettle();
    await tester.tap(_key('topup-continue'));
    await tester.pumpAndSettle();
    await tester.tap(_key('wallet-check-payment'));
    await tester.pumpAndSettle();
    expect(find.textContaining("hasn't confirmed"), findsOneWidget);
    expect(find.textContaining('Finish paying in Paystack'), findsOneWidget);

    wallet.failTopUpWith = "Payments aren't switched on yet.";
    await tester.tap(_key('wallet-add-money'));
    await tester.pumpAndSettle();
    await tester.tap(_key('topup-continue'));
    await tester.pumpAndSettle();
    expect(find.text("Payments aren't switched on yet."), findsOneWidget);
  });

  group('payment picker', () {
    Future<PaymentChoice?> pick(WidgetTester tester, {required int balance, required int fare, String tap = 'pay-wallet'}) async {
      PaymentChoice chosen = PaymentChoice.cash;
      await tester.pumpWidget(_host(
        StatefulBuilder(builder: (context, setState) => Consumer(
              builder: (context, ref, _) => Column(children: [
                PaymentPicker(value: chosen, fareNaira: fare, onChanged: (p) => setState(() => chosen = p)),
                Text('sends ${effectivePayment(ref, chosen, fare).db}'),
              ]),
            )),
        _FakeWallet(balance),
      ));
      await tester.pumpAndSettle();
      await tester.tap(_key(tap));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('wallet is chosen when it covers the fare', (tester) async {
      expect(await pick(tester, balance: 300000, fare: 2500), PaymentChoice.wallet);
      expect(find.text('sends wallet'), findsOneWidget);
    });

    testWidgets('wallet is unavailable when the balance is too low', (tester) async {
      await pick(tester, balance: 100000, fare: 2500);
      expect(find.text('sends cash'), findsOneWidget);
      expect(find.textContaining('Add money in the Wallet tab'), findsOneWidget);
    });
  });
}
