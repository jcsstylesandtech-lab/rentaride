import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

/// One line of wallet history.
class WalletEntry {
  const WalletEntry({
    required this.type,
    required this.amountKobo,
    required this.balanceAfterKobo,
    required this.createdAt,
    this.note,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> j) => WalletEntry(
        type: j['type'] as String,
        amountKobo: (j['amount_kobo'] as num).toInt(),
        balanceAfterKobo: (j['balance_after_kobo'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
        note: j['note'] as String?,
      );

  final String type;
  final int amountKobo;
  final int balanceAfterKobo;
  final DateTime createdAt;
  final String? note;

  String get title => switch (type) {
        'top_up' => 'Money added',
        'ride_payment' => 'Trip payment',
        'refund' => 'Refund',
        'adjustment' => 'Adjustment',
        _ => note ?? 'Wallet',
      };
}

/// Paystack checkout to open for a top-up.
class TopUpCheckout {
  const TopUpCheckout(this.reference, this.url);
  final String reference;
  final Uri url;
}

/// A problem the passenger can act on; [message] is written for them.
class WalletFailure implements Exception {
  const WalletFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class WalletRepository {
  /// Live balance in kobo.
  Stream<int> watchBalance();
  Future<List<WalletEntry>> history();
  Future<TopUpCheckout> startTopUp(int amountKobo);

  /// Asks the server to confirm a top-up with Paystack. Returns
  /// `succeeded`, `pending` or `failed`; credits the wallet at most once.
  Future<String> verify(String reference);
}

class SupabaseWalletRepository implements WalletRepository {
  SupabaseWalletRepository(this._db);
  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  @override
  Stream<int> watchBalance() => _db
      .from('wallets')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', _uid)
      .map((rows) => rows.isEmpty ? 0 : (rows.first['balance_kobo'] as num).toInt());

  @override
  Future<List<WalletEntry>> history() async {
    final rows = await _db
        .from('wallet_transactions')
        .select('type, amount_kobo, balance_after_kobo, note, created_at')
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) WalletEntry.fromJson(r)];
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('payments', body: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] is String ? details['error'] as String : null;
      throw WalletFailure(message ?? 'Payments are unavailable right now. Try again shortly.');
    } catch (e) {
      if (e is WalletFailure) rethrow;
      throw const WalletFailure('Could not reach the server. Check your connection and try again.');
    }
  }

  @override
  Future<TopUpCheckout> startTopUp(int amountKobo) async {
    final data = await _call({'action': 'top_up', 'amount_kobo': amountKobo});
    return TopUpCheckout(data['reference'] as String, Uri.parse(data['authorization_url'] as String));
  }

  @override
  Future<String> verify(String reference) async {
    final data = await _call({'action': 'verify', 'reference': reference});
    return data['status'] as String;
  }
}

/// Null when the app runs on demo data (no backend configured).
final walletRepositoryProvider = Provider<WalletRepository?>(
  (ref) => AppConfig.hasBackend ? SupabaseWalletRepository(Supabase.instance.client) : null,
);

/// Live balance in kobo; null on demo data.
final walletBalanceProvider = StreamProvider<int?>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchBalance();
});

/// History, reloaded whenever the balance changes.
final walletHistoryProvider = FutureProvider<List<WalletEntry>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  ref.watch(walletBalanceProvider);
  return repo == null ? const [] : repo.history();
});

/// Wallet limits, mirrored from the server's platform settings.
abstract final class WalletLimits {
  static const minTopUpKobo = 50000; // ₦500
  static const maxTopUpKobo = 50000000; // ₦500,000
}
