import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel, Supabase;

import '../../core/config/app_config.dart';
import '../auth/presentation/controllers/auth_controller.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromMe,
    required this.sentAt,
  });

  final String text;
  final bool fromMe;
  final DateTime sentAt;
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.messages,
    this.unread = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ChatMessage> messages;
  final int unread;

  ChatMessage? get last => messages.isEmpty ? null : messages.last;

  Conversation copyWith({List<ChatMessage>? messages, int? unread}) =>
      Conversation(
        id: id,
        title: title,
        subtitle: subtitle,
        icon: icon,
        messages: messages ?? this.messages,
        unread: unread ?? this.unread,
      );
}

/// Conversations with Rent A Ride support and safety (driver chats join
/// during trips). Phase 3 connects this to the support desk and to trip
/// chat over Socket.IO; until then it runs in memory and support replies
/// automatically, saying so.
final messagesProvider =
    NotifierProvider<MessagesController, List<Conversation>>(
      MessagesController.new,
    );

final unreadMessagesProvider = Provider<int>(
  (ref) => ref.watch(messagesProvider).fold(0, (n, c) => n + c.unread),
);

class MessagesController extends Notifier<List<Conversation>> {
  static const supportId = 'support';
  static const safetyId = 'safety';

  /// Supabase conversation ids for the local 'support' / 'safety' threads.
  final _dbIds = <String, String>{};
  RealtimeChannel? _channel;

  bool get _live => AppConfig.hasBackend;

  @override
  List<Conversation> build() {
    // Rebuild for a different signed-in passenger.
    ref.watch(authControllerProvider.select((u) => u?.id));
    final name = ref.read(authControllerProvider)?.firstName ?? 'there';
    final now = DateTime.now();
    if (_live) {
      _dbIds.clear();
      ref.onDispose(() {
        final c = _channel;
        if (c != null) Supabase.instance.client.removeChannel(c);
      });
      Future.microtask(_connect);
    }
    return [
      Conversation(
        id: supportId,
        title: 'Rent A Ride Support',
        subtitle: 'Rides, fares, payments and your account',
        icon: Icons.support_agent_rounded,
        unread: _live ? 0 : 1,
        messages: [
          ChatMessage(
            text:
                'Hi $name, welcome to Rent A Ride! Message us any time '
                'about rides, fares, payments or your account.',
            fromMe: false,
            sentAt: now.subtract(const Duration(minutes: 2)),
          ),
        ],
      ),
      Conversation(
        id: safetyId,
        title: 'Safety team',
        subtitle: 'Report an incident or a safety concern',
        icon: Icons.shield_rounded,
        messages: [
          ChatMessage(
            text:
                'If you ever feel unsafe during a trip, press SOS on the '
                'trip screen. To report something after a trip, message us '
                'here with the date and what happened.',
            fromMe: false,
            sentAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      ),
    ];
  }

  // ---------- Live (Supabase) ----------
  /// Finds or opens the passenger's support and safety threads, loads their
  /// messages and listens for replies from the Rent A Ride team.
  Future<void> _connect() async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await db.from('conversations').select('id, kind').eq('user_id', uid)
          .inFilter('kind', ['support', 'safety']);
      for (final r in rows) {
        _dbIds[r['kind'] as String] = r['id'] as String;
      }
      for (final kind in [supportId, safetyId]) {
        if (_dbIds[kind] == null) {
          final created = await db.from('conversations').insert({'kind': kind, 'user_id': uid}).select('id').single();
          _dbIds[kind] = created['id'] as String;
        }
      }
      if (!ref.mounted) return;
      _channel = db
          .channel('passenger-messages-$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'conversation_id',
              value: _dbIds.values.toList(),
            ),
            callback: (_) => _reload(),
          )
          .subscribe();
      await _reload();
    } catch (_) {/* offline: threads stay local until next launch */}
  }

  /// Rebuilds both threads from the database (keeping the intro message).
  Future<void> _reload() async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser?.id;
    if (uid == null || _dbIds.isEmpty) return;
    final rows = await db.from('messages').select('conversation_id, sender_id, body, created_at, read_at')
        .inFilter('conversation_id', _dbIds.values.toList()).order('created_at').limit(500);
    if (!ref.mounted) return;
    state = [
      for (final c in state)
        () {
          final dbId = _dbIds[c.id];
          final mine = rows.where((r) => r['conversation_id'] == dbId);
          final intro = c.messages.isEmpty ? const <ChatMessage>[] : [c.messages.first];
          return c.copyWith(
            messages: [
              ...intro,
              for (final r in mine)
                ChatMessage(
                  text: r['body'] as String,
                  fromMe: r['sender_id'] == uid,
                  sentAt: DateTime.parse(r['created_at'] as String).toLocal(),
                ),
            ],
            unread: mine.where((r) => r['sender_id'] != uid && r['read_at'] == null).length,
          );
        }(),
    ];
  }

  void markRead(String id) {
    state = [for (final c in state) c.id == id ? c.copyWith(unread: 0) : c];
    final dbId = _dbIds[id];
    if (_live && dbId != null) {
      Supabase.instance.client.rpc('mark_conversation_read', params: {'p_conversation': dbId}).ignore();
    }
  }

  Future<void> send(String id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _append(
      id,
      ChatMessage(text: trimmed, fromMe: true, sentAt: DateTime.now()),
    );

    if (_live) {
      final db = Supabase.instance.client;
      final dbId = _dbIds[id];
      final uid = db.auth.currentUser?.id;
      if (dbId == null || uid == null) return;
      try {
        await db.from('messages').insert({'conversation_id': dbId, 'sender_id': uid, 'body': trimmed});
      } catch (_) {
        if (!ref.mounted) return;
        _append(id, ChatMessage(text: "Couldn't send — check your connection and try again.", fromMe: false, sentAt: DateTime.now()));
      }
      return;
    }

    // Demo: automatic acknowledgement until the support desk is connected.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!ref.mounted) return;
    final team = id == safetyId ? 'Our safety team' : 'A support agent';
    _append(
      id,
      ChatMessage(
        text:
            'Thanks, we got your message. $team will reply here. '
            '(Demo mode: this reply is automatic.)',
        fromMe: false,
        sentAt: DateTime.now(),
      ),
    );
  }

  void _append(String id, ChatMessage message) {
    state = [
      for (final c in state)
        c.id == id ? c.copyWith(messages: [...c.messages, message]) : c,
    ];
  }
}
