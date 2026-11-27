import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_chat/rar_chat.dart';

void main() {
  testWidgets('chat and call stay hidden unless driver and rider are matched', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: RideContactButtons(rideId: 'r1', live: false, peerLabel: 'Your driver')),
    ));
    expect(find.byKey(const ValueKey('ride-chat')), findsNothing);
    expect(find.byKey(const ValueKey('ride-call')), findsNothing);
  });

  test('message rows parse, including read receipts', () {
    final m = LiveChatMessage.fromRow({
      'id': 'm1', 'body': 'On my way', 'sender_id': 'u1',
      'created_at': '2026-11-27T17:00:34Z', 'read_at': '2026-11-27T17:01:00Z',
    });
    expect(m.body, 'On my way');
    expect(m.readAt, isNotNull);
    expect(m.delivery, DeliveryState.sent);
    expect(m.copyWith(delivery: DeliveryState.failed).readAt, m.readAt);
  });
}
