import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a message is in its journey to the server.
enum DeliveryState { sent, sending, failed }

/// How the chat's live connection is doing (shown as a small banner).
enum ChatConnection { connecting, live, reconnecting }

@immutable
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.body,
    required this.senderId,
    required this.createdAt,
    this.readAt,
    this.delivery = DeliveryState.sent,
  });

  factory LiveChatMessage.fromRow(Map<String, dynamic> r) => LiveChatMessage(
        id: r['id'] as String,
        body: r['body'] as String,
        senderId: r['sender_id'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        readAt: r['read_at'] == null ? null : DateTime.parse(r['read_at'] as String).toLocal(),
      );

  final String id;
  final String body;
  final String senderId;
  final DateTime createdAt;
  final DateTime? readAt;
  final DeliveryState delivery;

  LiveChatMessage copyWith({DeliveryState? delivery, DateTime? readAt}) => LiveChatMessage(
        id: id, body: body, senderId: senderId, createdAt: createdAt,
        readAt: readAt ?? this.readAt, delivery: delivery ?? this.delivery);
}

/// One live conversation (support, safety or ride chat).
///
/// Messages arrive over Supabase Realtime. Because a phone drops its
/// connection when it sleeps or changes network, the controller also
/// reloads everything whenever the connection (re)joins and whenever the
/// app comes back to the foreground, so a reply is never missed. Typing
/// indicators go over a private broadcast channel (`chat:<id>`) that only
/// people in the conversation can join.
class LiveChatController extends ChangeNotifier {
  LiveChatController({required SupabaseClient db, required this.conversationId}) : _db = db;

  final SupabaseClient _db;
  final String conversationId;

  final List<LiveChatMessage> _messages = [];
  List<LiveChatMessage> get messages => List.unmodifiable(_messages);

  bool loading = true;
  String? loadError;
  bool peerTyping = false;
  ChatConnection connection = ChatConnection.connecting;

  /// True while a chat screen shows this conversation; incoming messages
  /// are then marked read straight away.
  bool _visible = false;
  bool get visible => _visible;
  set visible(bool v) {
    _visible = v;
    if (v) markRead();
  }

  String? get myId => _db.auth.currentUser?.id;

  /// Messages from the other side that haven't been read yet.
  int get unread => _messages.where((m) => m.senderId != myId && m.readAt == null).length;

  RealtimeChannel? _rows;
  RealtimeChannel? _typing;
  AppLifecycleListener? _lifecycle;
  Timer? _reconnect;
  Timer? _typingOff;
  Timer? _markReadSoon;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  int _attempt = 0;
  bool _started = false;
  bool _disposed = false;

  void start() {
    if (_started) return;
    _started = true;
    _lifecycle = AppLifecycleListener(onResume: () {
      // Back from the background: the socket may have been dropped.
      if (connection != ChatConnection.live) {
        _reconnectNow();
      } else {
        resync();
      }
    });
    _connect();
    resync();
  }

  void _connect() {
    if (_disposed) return;
    _rows = _db
        .channel('chat-rows:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (p) => _onRow(p.newRecord),
        )
        .subscribe((status, _) {
      if (_disposed) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _attempt = 0;
          _set(() => connection = ChatConnection.live);
          resync(); // catch up on anything sent while we were away
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          _scheduleReconnect();
      }
    });

    _typing = _db
        .channel('chat:$conversationId', opts: const RealtimeChannelConfig(private: true))
        .onBroadcast(event: 'typing', callback: (msg) {
          final payload = msg['payload'] is Map ? Map<String, dynamic>.from(msg['payload'] as Map) : msg;
          if (payload['user_id'] == myId) return;
          _typingOff?.cancel();
          _set(() => peerTyping = true);
          _typingOff = Timer(const Duration(seconds: 4), () => _set(() => peerTyping = false));
        })
        .subscribe();
  }

  void _scheduleReconnect() {
    if (_disposed || (_reconnect?.isActive ?? false)) return;
    _set(() => connection = ChatConnection.reconnecting);
    final seconds = math.min(30, 1 << math.min(_attempt, 5));
    _attempt++;
    _reconnect = Timer(Duration(seconds: seconds), _reconnectNow);
  }

  Future<void> _reconnectNow() async {
    _reconnect?.cancel();
    await _drop();
    _connect();
  }

  Future<void> _drop() async {
    final rows = _rows, typing = _typing;
    _rows = null;
    _typing = null;
    if (rows != null) await _db.removeChannel(rows);
    if (typing != null) await _db.removeChannel(typing);
  }

  void _onRow(Map<String, dynamic> row) {
    if (row['id'] == null || row['body'] == null) return;
    final m = LiveChatMessage.fromRow(row);
    final i = _messages.indexWhere((x) => x.id == m.id);
    _set(() {
      if (i >= 0) {
        _messages[i] = m;
      } else {
        _messages.add(m);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      if (m.senderId != myId) peerTyping = false;
    });
    if (_visible && m.senderId != myId && m.readAt == null) _scheduleMarkRead();
  }

  /// Reloads the whole conversation from the database.
  Future<void> resync() async {
    try {
      final rows = await _db
          .from('messages')
          .select('id, sender_id, body, created_at, read_at')
          .eq('conversation_id', conversationId)
          .order('created_at')
          .limit(500);
      if (_disposed) return;
      final local = _messages.where((m) => m.delivery != DeliveryState.sent).toList();
      _set(() {
        _messages
          ..clear()
          ..addAll(rows.map(LiveChatMessage.fromRow))
          ..addAll(local);
        loading = false;
        loadError = null;
      });
      if (_visible && unread > 0) _scheduleMarkRead();
    } catch (_) {
      if (_disposed) return;
      _set(() {
        loading = false;
        if (_messages.isEmpty) loadError = "Couldn't load messages. Check your connection.";
      });
    }
  }

  Future<void> send(String text) async {
    final body = text.trim();
    final me = myId;
    if (body.isEmpty || me == null) return;
    final temp = LiveChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      body: body,
      senderId: me,
      createdAt: DateTime.now(),
      delivery: DeliveryState.sending,
    );
    _set(() => _messages.add(temp));
    await _deliver(temp);
  }

  /// Tries a failed message again.
  Future<void> retry(LiveChatMessage m) async {
    final i = _messages.indexWhere((x) => x.id == m.id);
    if (i < 0) return;
    _set(() => _messages[i] = m.copyWith(delivery: DeliveryState.sending));
    await _deliver(_messages[i]);
  }

  Future<void> _deliver(LiveChatMessage temp) async {
    try {
      final row = await _db
          .from('messages')
          .insert({'conversation_id': conversationId, 'sender_id': temp.senderId, 'body': temp.body})
          .select('id, sender_id, body, created_at, read_at')
          .single();
      if (_disposed) return;
      final saved = LiveChatMessage.fromRow(row);
      _set(() {
        _messages.removeWhere((x) => x.id == temp.id || x.id == saved.id);
        _messages.add(saved);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    } catch (_) {
      if (_disposed) return;
      final i = _messages.indexWhere((x) => x.id == temp.id);
      if (i >= 0) _set(() => _messages[i] = temp.copyWith(delivery: DeliveryState.failed));
    }
  }

  /// Call as the person types; tells the other side, at most every 2 s.
  void typing() {
    final now = DateTime.now();
    final ch = _typing;
    final me = myId;
    if (ch == null || me == null || now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
    _lastTypingSent = now;
    ch.sendBroadcastMessage(event: 'typing', payload: {'user_id': me}).ignore();
  }

  void _scheduleMarkRead() {
    _markReadSoon?.cancel();
    _markReadSoon = Timer(const Duration(milliseconds: 400), markRead);
  }

  Future<void> markRead() async {
    if (_disposed || unread == 0) return;
    try {
      await _db.rpc('mark_conversation_read', params: {'p_conversation': conversationId});
      final now = DateTime.now();
      _set(() {
        for (var i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          if (m.senderId != myId && m.readAt == null) _messages[i] = m.copyWith(readAt: now);
        }
      });
    } catch (_) {/* retried on the next message or resync */}
  }

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _typingOff?.cancel();
    _markReadSoon?.cancel();
    _lifecycle?.dispose();
    _drop();
    super.dispose();
  }
}
