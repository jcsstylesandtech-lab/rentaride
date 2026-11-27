import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

import 'live_chat_controller.dart';

String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Messages, typing bubble and reply box for one [LiveChatController].
class LiveChatView extends StatefulWidget {
  const LiveChatView({
    super.key,
    required this.controller,
    required this.peerLabel,
    this.dark = false,
    this.intro,
    this.readOnlyNote,
  });

  final LiveChatController controller;

  /// Who is on the other side, e.g. "Support" or "Your driver".
  final String peerLabel;
  final bool dark;

  /// Shown as the first incoming bubble (a greeting or how-to).
  final String? intro;

  /// When set, the reply box is replaced by this note.
  final String? readOnlyNote;

  @override
  State<LiveChatView> createState() => _LiveChatViewState();
}

class _LiveChatViewState extends State<LiveChatView> {
  final _input = TextEditingController();

  LiveChatController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.visible = true;
  }

  @override
  void dispose() {
    c.visible = false;
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    setState(() {});
    c.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final muted = dark ? RarColors.textOnDarkMuted : RarColors.textMuted;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final me = c.myId;
        final items = c.messages.reversed.toList();
        final extra = (c.peerTyping ? 1 : 0);
        final introCount = widget.intro == null ? 0 : 1;
        return Column(children: [
          if (c.connection == ChatConnection.reconnecting)
            Container(
              key: const ValueKey('chat-reconnecting'),
              width: double.infinity,
              color: RarColors.warning.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Text('Reconnecting… new messages will appear when you are back online.',
                  style: RarTypography.caption.copyWith(color: dark ? RarColors.white : RarColors.navy)),
            ),
          Expanded(
            child: c.loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : c.loadError != null && items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(RarSpacing.xl),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(c.loadError!, textAlign: TextAlign.center, style: RarTypography.body.copyWith(color: muted)),
                            const SizedBox(height: RarSpacing.md),
                            TextButton(onPressed: c.resync, child: const Text('Try again')),
                          ]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: c.resync,
                        child: ListView.builder(
                          reverse: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(RarSpacing.lg),
                          itemCount: extra + items.length + introCount,
                          itemBuilder: (context, i) {
                            if (c.peerTyping && i == 0) {
                              return RarTypingBubble(key: const ValueKey('typing'), label: widget.peerLabel, dark: dark);
                            }
                            final j = i - extra;
                            if (j == items.length) {
                              return _Bubble(text: widget.intro!, mine: false, time: null, dark: dark);
                            }
                            final m = items[j];
                            final mine = m.senderId == me;
                            return _Bubble(
                              text: m.body,
                              mine: mine,
                              time: m.createdAt,
                              dark: dark,
                              delivery: m.delivery,
                              seen: mine && m.readAt != null,
                              onRetry: m.delivery == DeliveryState.failed ? () => c.retry(m) : null,
                            );
                          },
                        ),
                      ),
          ),
          if (widget.readOnlyNote != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(RarSpacing.lg),
                child: Text(widget.readOnlyNote!, textAlign: TextAlign.center, style: RarTypography.bodySmall.copyWith(color: muted)),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: dark ? RarColors.navy900 : RarColors.white,
                  border: Border(top: BorderSide(color: dark ? RarColors.glassBorderDark : RarColors.outlineLight)),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: dark ? RarColors.white : RarColors.navy),
                      onChanged: (_) {
                        setState(() {});
                        c.typing();
                      },
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Write a message',
                        hintStyle: TextStyle(color: muted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.time,
    required this.dark,
    this.delivery = DeliveryState.sent,
    this.seen = false,
    this.onRetry,
  });

  final String text;
  final bool mine;
  final DateTime? time;
  final bool dark;
  final DeliveryState delivery;
  final bool seen;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theirs = dark ? RarColors.glassFillDarkStrong : RarColors.white;
    final textColor = mine ? RarColors.white : (dark ? RarColors.white : RarColors.navy);
    final meta = mine ? RarColors.textOnDarkSecondary : (dark ? RarColors.textOnDarkMuted : RarColors.textMuted);
    final status = switch (delivery) {
      DeliveryState.sending => 'Sending…',
      DeliveryState.failed => 'Not sent · tap to retry',
      DeliveryState.sent => [if (time != null) _time(time!), if (seen) 'Seen'].join(' · '),
    };
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: RarSpacing.sm),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: mine ? (delivery == DeliveryState.failed ? RarColors.danger : RarColors.royal) : theirs,
        border: mine ? null : Border.all(color: dark ? RarColors.glassBorderDark : RarColors.outlineLight),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Align(alignment: Alignment.centerLeft, child: Text(text, style: RarTypography.body.copyWith(color: textColor))),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(status, style: RarTypography.caption.copyWith(fontSize: 10, color: meta)),
        ],
      ]),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: onRetry == null ? bubble : GestureDetector(onTap: onRetry, child: bubble),
      ),
    );
  }
}
