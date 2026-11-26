import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_driver/data/payouts_repository.dart';
import 'package:rent_a_ride_driver/screens/payouts_section.dart';

class _FakePayouts implements PayoutsRepository {
  _FakePayouts({this.balance = 0, this.due = 0, this.account});
  int balance;
  int due;
  PayoutAccount? account;
  final requested = <int>[];
  final withdrawals = <Withdrawal>[];

  @override
  Stream<DriverWallet> watchWallet() => Stream.value(DriverWallet(balanceKobo: balance, commissionDueKobo: due));
  @override
  Stream<List<Withdrawal>> watchWithdrawals() => Stream.value(withdrawals);
  @override
  Future<PayoutAccount?> payoutAccount() async => account;
  @override
  Future<int> minWithdrawalKobo() async => 100000;
  @override
  Future<List<Bank>> banks() async => const [Bank('Access Bank', '044'), Bank('Guaranty Trust Bank', '058')];
  @override
  Future<PayoutAccount> savePayoutAccount({required String bankCode, required String accountNumber}) async {
    if (accountNumber == '0000000000') {
      throw const PayoutFailure("We couldn't find that account at this bank. Check the number and bank.");
    }
    return account = PayoutAccount(
        bankName: bankCode == '058' ? 'Guaranty Trust Bank' : 'Access Bank', accountNumber: accountNumber, accountName: 'IBRAHIM MUSA');
  }

  @override
  Future<void> requestWithdrawal(int amountKobo) async => requested.add(amountKobo);
}

Widget _host(_FakePayouts repo) => ProviderScope(
      overrides: [payoutsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: RarTheme.dark(),
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: const [PayoutsSection()])),
      ),
    );

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no bank account: balance, commission owed, withdraw disabled', (tester) async {
    await tester.pumpWidget(_host(_FakePayouts(balance: 250000, due: 15000)));
    await tester.pumpAndSettle();
    expect(find.text('₦2,500'), findsOneWidget);
    expect(find.textContaining('Commission owed from cash trips: ₦150'), findsOneWidget);
    expect(find.text('Add a bank account to withdraw.'), findsOneWidget);
    expect(tester.widget<RarButton>(_key('withdraw')).onPressed, isNull);
  });

  testWidgets('adds a bank account after the server checks it', (tester) async {
    final repo = _FakePayouts(balance: 250000);
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    await _tap(tester, _key('payout-account-edit'));

    await _tap(tester, _key('bank-save'));
    expect(find.text('Choose your bank.'), findsOneWidget);

    await _tap(tester, _key('bank-picker'));
    await _tap(tester, find.text('Guaranty Trust Bank').last);
    final number = find.descendant(of: _key('account-number'), matching: find.byType(EditableText));
    await tester.enterText(number, '12345');
    await _tap(tester, _key('bank-save'));
    expect(find.text('Enter your 10-digit account number.'), findsOneWidget);

    await tester.enterText(number, '0000000000');
    await _tap(tester, _key('bank-save'));
    expect(find.textContaining("couldn't find that account"), findsOneWidget);

    await tester.enterText(number, '0123456789');
    await _tap(tester, _key('bank-save'));
    expect(find.text('Payouts will go to IBRAHIM MUSA, Guaranty Trust Bank.'), findsOneWidget);
    expect(find.text('Guaranty Trust Bank · •••6789'), findsOneWidget);
    expect(tester.widget<RarButton>(_key('withdraw')).onPressed, isNotNull);
  });

  testWidgets('withdraws within the balance and minimum', (tester) async {
    final repo = _FakePayouts(
      balance: 500000,
      account: const PayoutAccount(bankName: 'Access Bank', accountNumber: '0123456789', accountName: 'IBRAHIM MUSA'),
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    await _tap(tester, _key('withdraw'));

    final amount = find.descendant(of: _key('withdraw-amount'), matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(amount).controller.text, '5000');
    await tester.enterText(amount, '500');
    await _tap(tester, _key('withdraw-submit'));
    expect(find.text('The minimum withdrawal is ₦1,000.'), findsOneWidget);
    await tester.enterText(amount, '9000');
    await _tap(tester, _key('withdraw-submit'));
    expect(find.text("You can't withdraw more than your balance."), findsOneWidget);
    expect(repo.requested, isEmpty);

    await tester.enterText(amount, '3000');
    await _tap(tester, _key('withdraw-submit'));
    expect(repo.requested, [300000]);
    expect(find.textContaining('Withdrawal requested'), findsOneWidget);
  });

  testWidgets('below the minimum explains when withdrawals open', (tester) async {
    await tester.pumpWidget(_host(_FakePayouts(
      balance: 50000,
      account: const PayoutAccount(bankName: 'Access Bank', accountNumber: '0123456789', accountName: 'IBRAHIM MUSA'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('You can withdraw once your balance reaches ₦1,000.'), findsOneWidget);
  });
}
