import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'conversations.dart';
import 'live_chat_controller.dart';
import 'live_chat_view.dart';

/// A full-screen chat. Pass [controller] to reuse a live one (it then stays
/// open after the screen closes), or [open] to look up the conversation.
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({
    super.key,
    required this.title,
    required this.peerLabel,
    this.subtitle,
    this.icon = Icons.support_agent_rounded,
    this.controller,
    this.open,
    this.dark = false,
    this.intro,
    this.actions = const [],
  }) : assert(controller != null || open != null);

  final String title;
  final String? subtitle;
  final IconData icon;
  final String peerLabel;
  final LiveChatController? controller;
  final Future<String> Function()? open;
  final bool dark;
  final String? intro;
  final List<Widget> actions;

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  LiveChatController? _own;
  String? _error;

  LiveChatController? get _controller => widget.controller ?? _own;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final id = await widget.open!();
      if (!mounted) return;
      setState(() => _own = LiveChatController(db: Supabase.instance.client, conversationId: id)..start());
    } on ChatUnavailable catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final c = _controller;
    final body = c != null
        ? LiveChatView(controller: c, peerLabel: widget.peerLabel, dark: dark, intro: widget.intro)
        : Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(RarSpacing.xl),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center,
                          style: RarTypography.body.copyWith(color: dark ? RarColors.white : RarColors.navy)),
                      const SizedBox(height: RarSpacing.md),
                      TextButton(onPressed: _load, child: const Text('Try again')),
                    ]),
                  ),
          );
    return Theme(
      data: dark ? RarTheme.dark() : RarTheme.light(),
      child: Scaffold(
        backgroundColor: dark ? RarColors.navy : RarColors.background,
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: dark ? RarColors.navy900 : null,
          title: Row(children: [
            Icon(widget.icon, color: dark ? RarColors.cyan : RarColors.royal),
            const SizedBox(width: RarSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: RarTypography.titleSmall.copyWith(color: dark ? RarColors.white : RarColors.navy)),
                if (widget.subtitle != null)
                  Text(widget.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: RarTypography.caption.copyWith(
                          color: dark ? RarColors.textOnDarkSecondary : RarColors.textSecondary)),
              ]),
            ),
          ]),
          actions: widget.actions,
        ),
        body: body,
      ),
    );
  }
}

/// Places a phone call through the device dialer, with a friendly
/// message when it can't. Returns null on success, or a message to show.
Future<String?> callRideContact(String rideId) async {
  try {
    final phone = await rideContactPhone(Supabase.instance.client, rideId);
    if (phone == null) return "They haven't added a phone number. Send a message instead.";
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    return ok ? null : "This device can't make phone calls. Send a message instead.";
  } on ChatUnavailable catch (e) {
    return e.message;
  }
}

/// Chat and Call buttons for a matched trip. Shows nothing unless
/// [live] is true (driver accepted, arrived, or trip in progress), so the
/// two people can only reach each other while they are connected for a
/// pickup. Shows an unread badge when the other person writes.
class RideContactButtons extends StatefulWidget {
  const RideContactButtons({
    super.key,
    required this.rideId,
    required this.live,
    required this.peerLabel,
    this.peerName,
    this.dark = false,
  });

  final String rideId;
  final bool live;

  /// "Your driver" or "Your rider".
  final String peerLabel;
  final String? peerName;
  final bool dark;

  @override
  State<RideContactButtons> createState() => _RideContactButtonsState();
}

class _RideContactButtonsState extends State<RideContactButtons> {
  LiveChatController? _chat;
  bool _calling = false;
  String? _openError;

  @override
  void initState() {
    super.initState();
    if (widget.live) _open();
  }

  @override
  void didUpdateWidget(RideContactButtons old) {
    super.didUpdateWidget(old);
    if (old.rideId != widget.rideId || old.live != widget.live) {
      _chat?.dispose();
      _chat = null;
      if (widget.live) _open();
    }
  }

  Future<void> _open() async {
    try {
      final id = await openRideConversation(Supabase.instance.client, widget.rideId);
      if (!mounted || !widget.live) return;
      setState(() => _chat = LiveChatController(db: Supabase.instance.client, conversationId: id)..start());
    } on ChatUnavailable catch (e) {
      if (mounted) setState(() => _openError = e.message);
    }
  }

  @override
  void dispose() {
    _chat?.dispose();
    super.dispose();
  }

  void _toast(String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  void _openChat() {
    final c = _chat;
    if (c == null) {
      _toast(_openError ?? 'Opening the chat… try again in a moment.');
      if (_openError != null) _open();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LiveChatScreen(
        title: widget.peerName ?? widget.peerLabel,
        subtitle: 'Chat closes when the trip ends',
        icon: Icons.chat_bubble_rounded,
        peerLabel: widget.peerName ?? widget.peerLabel,
        controller: c,
        dark: widget.dark,
        actions: [
          IconButton(tooltip: 'Call', icon: const Icon(Icons.call_rounded), onPressed: _call),
        ],
      ),
    ));
  }

  Future<void> _call() async {
    if (_calling) return;
    setState(() => _calling = true);
    final problem = await callRideContact(widget.rideId);
    if (!mounted) return;
    setState(() => _calling = false);
    if (problem != null) _toast(problem);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.live) return const SizedBox.shrink();
    final c = _chat;
    Widget chatButton(int unread) => Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: OutlinedButton.icon(
            key: const ValueKey('ride-chat'),
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: Text(unread > 0 ? 'New message' : 'Chat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.dark ? RarColors.white : RarColors.royal,
              side: BorderSide(color: widget.dark ? RarColors.glassBorderDark : RarColors.outlineLight),
              minimumSize: const Size(0, 48),
            ),
          ),
        );
    return Row(children: [
      Expanded(child: c == null ? chatButton(0) : ListenableBuilder(listenable: c, builder: (_, _) => chatButton(c.unread))),
      const SizedBox(width: RarSpacing.sm),
      Expanded(
        child: FilledButton.icon(
          key: const ValueKey('ride-call'),
          onPressed: _calling ? null : _call,
          icon: _calling
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.call_rounded, size: 18),
          label: const Text('Call'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ),
    ]);
  }
}
