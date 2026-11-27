import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('shows the initial without a photo and is not tappable', (t) async {
    await t.pumpWidget(host(const RarAvatar(name: 'ada obi')));
    expect(find.text('A'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
  });

  testWidgets('edit badge calls onEdit, but not while busy', (t) async {
    var taps = 0;
    await t.pumpWidget(host(RarAvatar(name: 'Ada', onEdit: () => taps++)));
    await t.tap(find.byType(RarAvatar));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);

    await t.pumpWidget(host(RarAvatar(name: 'Ada', busy: true, onEdit: () => taps++)));
    await t.tap(find.byType(RarAvatar));
    expect(taps, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('photo sheet offers remove only when a photo exists', (t) async {
    PhotoSourceChoice? picked;
    await t.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () async => picked = await showPhotoSourceSheet(context, hasPhoto: true),
        child: const Text('open'),
      ),
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Remove photo'), findsOneWidget);
    await t.tap(find.text('Choose from photos'));
    await t.pumpAndSettle();
    expect(picked, PhotoSourceChoice.gallery);
  });
}
