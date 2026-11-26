import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/providers.dart' show supabaseProvider;

/// Driver wallet: balance after commission, and commission still owed from
/// cash trips (taken from the next earnings or top-up).
class DriverWallet {
  const DriverWallet({required this.balanceKobo, required this.commissionDueKobo});
  final int balanceKobo;
  final int commissionDueKobo;
}

class Bank {
  const Bank(this.name, this.code);
  final String name;
  final String code;
}

class PayoutAccount {
  const PayoutAccount({required this.bankName, required this.accountNumber, required this.accountName});
  factory PayoutAccount.fromJson(Map<String, dynamic> j) => PayoutAccount(
        bankName: j['bank_name'] as String,
        accountNumber: j['account_number'] as String,
        accountName: j['account_name'] as String,
      );
  final String bankName;
  final String accountNumber;
  final String accountName;

  String get masked => '•••${accountNumber.substring(accountNumber.length - 4)}';
}

class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amountKobo,
    required this.status,
    required this.bankName,
    required this.accountNumber,
    required this.createdAt,
    this.failureReason,
  });
  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
        id: j['id'] as String,
        amountKobo: (j['amount_kobo'] as num).toInt(),
        status: j['status'] as String,
        bankName: j['bank_name'] as String,
        accountNumber: j['account_number'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        failureReason: j['failure_reason'] as String?,
      );
  final String id;
  final int amountKobo;

  /// requested, processing, paid, failed or rejected.
  final String status;
  final String bankName;
  final String accountNumber;
  final DateTime createdAt;
  final String? failureReason;

  String get statusLabel => switch (status) {
        'requested' => 'Waiting for review',
        'processing' => 'Sending to your bank',
        'paid' => 'Paid',
        'failed' => 'Failed · money returned',
        'rejected' => 'Rejected · money returned',
        _ => status,
      };
}

/// A problem the driver can act on; [message] is written for them.
class PayoutFailure implements Exception {
  const PayoutFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class PayoutsRepository {
  Stream<DriverWallet> watchWallet();
  Stream<List<Withdrawal>> watchWithdrawals();
  Future<PayoutAccount?> payoutAccount();
  Future<int> minWithdrawalKobo();
  Future<List<Bank>> banks();
  Future<PayoutAccount> savePayoutAccount({required String bankCode, required String accountNumber});
  Future<void> requestWithdrawal(int amountKobo);
}

class SupabasePayoutsRepository implements PayoutsRepository {
  SupabasePayoutsRepository(this._db);
  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  @override
  Stream<DriverWallet> watchWallet() => _db
      .from('wallets')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', _uid)
      .map((rows) => rows.isEmpty
          ? const DriverWallet(balanceKobo: 0, commissionDueKobo: 0)
          : DriverWallet(
              balanceKobo: (rows.first['balance_kobo'] as num).toInt(),
              commissionDueKobo: (rows.first['commission_due_kobo'] as num? ?? 0).toInt(),
            ));

  @override
  Stream<List<Withdrawal>> watchWithdrawals() => _db
      .from('withdrawals')
      .stream(primaryKey: ['id'])
      .eq('driver_id', _uid)
      .order('created_at')
      .map((rows) => [for (final r in rows.reversed.take(20)) Withdrawal.fromJson(r)]);

  @override
  Future<PayoutAccount?> payoutAccount() async {
    final row = await _db
        .from('payout_accounts')
        .select('bank_name, account_number, account_name')
        .eq('driver_id', _uid)
        .maybeSingle();
    return row == null ? null : PayoutAccount.fromJson(row);
  }

  @override
  Future<int> minWithdrawalKobo() async {
    final row = await _db.from('platform_settings').select('min_withdrawal_kobo').maybeSingle();
    return (row?['min_withdrawal_kobo'] as num? ?? 100000).toInt();
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('payments', body: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      throw PayoutFailure(d is Map && d['error'] is String
          ? d['error'] as String
          : 'Payouts are unavailable right now. Try again shortly.');
    } catch (e) {
      if (e is PayoutFailure) rethrow;
      throw const PayoutFailure('Could not reach the server. Check your connection and try again.');
    }
  }

  @override
  Future<List<Bank>> banks() async {
    final data = await _call({'action': 'banks'});
    return [for (final b in data['banks'] as List) Bank(b['name'] as String, b['code'] as String)];
  }

  @override
  Future<PayoutAccount> savePayoutAccount({required String bankCode, required String accountNumber}) async {
    final data = await _call({'action': 'save_payout_account', 'bank_code': bankCode, 'account_number': accountNumber});
    return PayoutAccount.fromJson(data);
  }

  @override
  Future<void> requestWithdrawal(int amountKobo) async {
    try {
      await _db.rpc('request_withdrawal', params: {'p_amount_kobo': amountKobo});
    } on PostgrestException catch (e) {
      throw PayoutFailure(e.message == 'Insufficient wallet balance'
          ? "You can't withdraw more than your balance."
          : e.message);
    }
  }
}

final payoutsRepositoryProvider =
    Provider<PayoutsRepository>((ref) => SupabasePayoutsRepository(ref.watch(supabaseProvider)));

final driverWalletProvider = StreamProvider<DriverWallet>((ref) => ref.watch(payoutsRepositoryProvider).watchWallet());

final withdrawalsProvider =
    StreamProvider<List<Withdrawal>>((ref) => ref.watch(payoutsRepositoryProvider).watchWithdrawals());

final payoutAccountProvider =
    FutureProvider<PayoutAccount?>((ref) => ref.watch(payoutsRepositoryProvider).payoutAccount());

final minWithdrawalProvider = FutureProvider<int>((ref) => ref.watch(payoutsRepositoryProvider).minWithdrawalKobo());
