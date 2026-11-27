import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';

void main() {
  testWidgets('typing bubble shows who is typing and is announced', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: RarTypingBubble(label: 'Support'))));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Support is typing…'), findsOneWidget);
    expect(find.bySemanticsLabel('Support is typing'), findsOneWidget);
  });

  testWidgets('typing bubble stays still when animations are off', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: MediaQuery(data: MediaQueryData(disableAnimations: true), child: Scaffold(body: RarTypingBubble(label: 'Ada', dark: true))),
    ));
    await t.pumpAndSettle(); // would time out if it kept animating
    expect(find.text('Ada is typing…'), findsOneWidget);
  });
}
