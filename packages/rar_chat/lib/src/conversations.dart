import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown with a message written for the person using the app.
class ChatUnavailable implements Exception {
  const ChatUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The signed-in user's support or safety thread, opened on first use.
/// [kind] is `support` or `safety`.
Future<String> openTeamConversation(SupabaseClient db, String kind) async {
  final uid = db.auth.currentUser?.id;
  if (uid == null) throw const ChatUnavailable('Sign in to message the Rent A Ride team.');
  Future<String?> find() async {
    final row = await db.from('conversations').select('id').eq('user_id', uid).eq('kind', kind).maybeSingle();
    return row?['id'] as String?;
  }

  try {
    final existing = await find();
    if (existing != null) return existing;
    try {
      final created = await db.from('conversations').insert({'kind': kind, 'user_id': uid}).select('id').single();
      return created['id'] as String;
    } on PostgrestException catch (e) {
      // Opened on another device at the same moment (unique per user + kind).
      if (e.code == '23505') return (await find())!;
      rethrow;
    }
  } on ChatUnavailable {
    rethrow;
  } catch (_) {
    throw const ChatUnavailable("Couldn't open the chat. Check your connection and try again.");
  }
}

/// The chat between a rider and their driver. Works only while they are
/// matched (driver accepted, arrived, or trip in progress).
Future<String> openRideConversation(SupabaseClient db, String rideId) async {
  try {
    return await db.rpc('open_ride_chat', params: {'p_ride': rideId}) as String;
  } on PostgrestException catch (e) {
    throw ChatUnavailable(e.code == '42501' ? e.message : "Couldn't open the chat. Try again.");
  } catch (_) {
    throw const ChatUnavailable("Couldn't open the chat. Check your connection and try again.");
  }
}

/// The other person's phone number for the call button, or null when they
/// haven't added one. Works only while the trip is live.
Future<String?> rideContactPhone(SupabaseClient db, String rideId) async {
  try {
    final phone = await db.rpc('ride_contact_phone', params: {'p_ride': rideId}) as String?;
    return (phone == null || phone.trim().isEmpty) ? null : phone.trim();
  } on PostgrestException catch (e) {
    throw ChatUnavailable(e.code == '42501' ? e.message : "Couldn't start the call. Try again.");
  } catch (_) {
    throw const ChatUnavailable("Couldn't start the call. Check your connection and try again.");
  }
}
