import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  List<Conversation> build() {
    final name = ref.read(authControllerProvider)?.firstName ?? 'there';
    final now = DateTime.now();
    return [
      Conversation(
        id: supportId,
        title: 'Rent A Ride Support',
        subtitle: 'Rides, fares, payments and your account',
        icon: Icons.support_agent_rounded,
        unread: 1,
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

  void markRead(String id) {
    state = [for (final c in state) c.id == id ? c.copyWith(unread: 0) : c];
  }

  Future<void> send(String id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _append(
      id,
      ChatMessage(text: trimmed, fromMe: true, sentAt: DateTime.now()),
    );

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
