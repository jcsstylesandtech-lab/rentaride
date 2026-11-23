import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../home/presentation/widgets/account_tabs.dart';
import 'messages.dart';

String _time(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Opens the chat for [conversationId].
void openChat(BuildContext context, String conversationId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(conversationId: conversationId),
    ),
  );
}

/// List of conversations.
class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(messagesProvider);

    return TabPage(
      title: 'Messages',
      children: [
        for (final c in conversations) ...[
          _ConversationTile(
            conversation: c,
            onTap: () => openChat(context, c.id),
          ),
          const SizedBox(height: RarSpacing.md),
        ],
        const SizedBox(height: RarSpacing.sm),
        Container(
          padding: const EdgeInsets.all(RarSpacing.lg),
          decoration: BoxDecoration(
            color: RarColors.surfaceLight,
            borderRadius: RarRadius.card,
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: RarColors.royal),
              const SizedBox(width: RarSpacing.md),
              Expanded(
                child: Text(
                  'During a trip, your chat with the driver appears here. '
                  'Phone numbers stay private on both sides.',
                  style: RarTypography.bodySmall.copyWith(
                    color: RarColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final last = c.last;
    final unread = c.unread > 0;

    return Material(
      color: RarColors.white,
      borderRadius: RarRadius.card,
      child: InkWell(
        borderRadius: RarRadius.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(RarSpacing.md),
          decoration: BoxDecoration(
            borderRadius: RarRadius.card,
            border: Border.all(color: RarColors.outlineLight),
          ),
          child: Row(
            children: [
              IconTile(icon: c.icon, size: 46),
              const SizedBox(width: RarSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RarTypography.titleSmall,
                          ),
                        ),
                        if (last != null)
                          Text(
                            _time(last.sentAt),
                            style: RarTypography.caption.copyWith(
                              color: unread
                                  ? RarColors.royal
                                  : RarColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            last == null
                                ? c.subtitle
                                : '${last.fromMe ? 'You: ' : ''}${last.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RarTypography.bodySmall.copyWith(
                              color: unread
                                  ? RarColors.navy
                                  : RarColors.textSecondary,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: RarSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: RarColors.royal,
                              borderRadius: RarRadius.pillShape,
                            ),
                            child: Text(
                              '${c.unread}',
                              style: RarTypography.caption.copyWith(
                                color: RarColors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One conversation: messages and a box to reply.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(messagesProvider.notifier).markRead(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    setState(() {});
    ref.read(messagesProvider.notifier).send(widget.conversationId, text);
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref
        .watch(messagesProvider)
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    if (conversation == null) return const SizedBox.shrink();
    // Newest first, shown bottom-up, so the list starts at the latest.
    final messages = conversation.messages.reversed.toList();

    return Theme(
      data: RarTheme.light(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Row(
              children: [
                IconTile(icon: conversation.icon, size: 34),
                const SizedBox(width: RarSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(conversation.title, style: RarTypography.titleSmall),
                      Text(
                        conversation.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RarTypography.caption.copyWith(
                          color: RarColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(RarSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(message: messages[i]),
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration: const BoxDecoration(
                    color: RarColors.white,
                    border: Border(
                      top: BorderSide(color: RarColors.outlineLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('chat-input'),
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Write a message',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        key: const ValueKey('chat-send'),
                        tooltip: 'Send',
                        onPressed: _input.text.trim().isEmpty ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: RarSpacing.sm),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? RarColors.royal : RarColors.white,
            border: mine ? null : Border.all(color: RarColors.outlineLight),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.text,
                  style: RarTypography.body.copyWith(
                    color: mine ? RarColors.white : RarColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _time(message.sentAt),
                style: RarTypography.caption.copyWith(
                  fontSize: 10,
                  color: mine
                      ? RarColors.textOnDarkSecondary
                      : RarColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
