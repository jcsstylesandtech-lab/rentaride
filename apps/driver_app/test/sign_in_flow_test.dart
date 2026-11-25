import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_driver/app.dart';
import 'package:rent_a_ride_driver/state/providers.dart';

void main() {
  testWidgets('signing in closes the sign-in page and shows the account', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = StreamController<String?>();
    addTearDown(session.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) => session.stream),
        driverStateProvider.overrideWith((ref) async => const DriverState(
            profile: null, driver: null, vehicles: [], documents: [])),
      ],
      child: MaterialApp(
        navigatorKey: DriverApp.navigatorKey,
        theme: RarTheme.dark(),
        home: const AppGate(),
      ),
    ));
    session.add(null); // signed out
    await tester.pumpAndSettle();

    // Walk the intro to its last page, then use "sign in".
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('next')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.textContaining('sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, driver'), findsOneWidget);

    session.add('driver-1'); // Supabase reports a successful sign-in
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, driver'), findsNothing);
    // Profile null in this fake → the gate's "wrong account" screen, proving the
    // gate (not the sign-in page) is now showing.
    expect(find.text('This is a passenger account'), findsOneWidget);
  });
}
