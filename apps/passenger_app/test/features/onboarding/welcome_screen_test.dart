import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rent_a_ride_passenger/app/router/app_routes.dart';
import 'package:rent_a_ride_passenger/features/onboarding/presentation/screens/welcome_screen.dart';

import '../../helpers/test_app.dart';

/// The welcome screen alone, with a stand-in for the Get Started screen.
Widget _app() => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.getStarted,
        builder: (context, state) =>
            const Scaffold(body: Text('get-started-screen')),
      ),
    ],
  ),
);

// The background map animates continuously, so wait fixed times instead of
// pumpAndSettle.
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  setUpAll(loadBrandFonts);

  testWidgets('Next moves through the pages, Get Started opens sign-up', (
    tester,
  ) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(_app());
    await _wait(tester);

    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    expect(_key('next'), findsOneWidget);

    await tester.tap(_key('next'));
    await _wait(tester);
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);

    await tester.tap(_key('next'));
    await _wait(tester);
    expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);
    expect(_key('get-started'), findsOneWidget);

    await tester.tap(_key('get-started'));
    await _wait(tester);
    expect(find.text('get-started-screen'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} '
        'with large text', (tester) async {
      setScreen(tester, size, textScale: 1.3);
      await tester.pumpWidget(_app());
      await _wait(tester);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 2; i++) {
        await tester.tap(_key('next'));
        await _wait(tester);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
