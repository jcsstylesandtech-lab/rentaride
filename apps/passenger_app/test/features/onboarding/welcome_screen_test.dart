import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_passenger/features/auth/presentation/screens/auth_entry_screen.dart';
import 'package:rent_a_ride_passenger/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:rent_a_ride_passenger/features/onboarding/presentation/widgets/feature_detail_sheet.dart';

import '../../helpers/test_app.dart';

const _phone = Size(390, 844);

Finder get _createAccount => find.byKey(const ValueKey('create-account'));
Finder get _logIn => find.byKey(const ValueKey('log-in'));

AuthEntryMode? _currentAuthMode(WidgetTester tester) {
  final screens = find.byType(AuthEntryScreen);
  if (screens.evaluate().isEmpty) return null;
  return tester.widget<AuthEntryScreen>(screens.last).mode;
}

void main() {
  setUpAll(loadBrandFonts);

  group('Welcome screen content', () {
    testWidgets('shows branding, headline, features and actions', (
      tester,
    ) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(RarWordmark), findsOneWidget);
      expect(find.text('Safe  •  Reliable  •  Affordable'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Your Ride. Your Destination. Your Choice.'),
        findsOneWidget,
      );
      for (final title in ['Ride', 'Delivery', 'Explore', 'Safety']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(_createAccount, findsOneWidget);
      expect(_logIn, findsOneWidget);
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    });
  });

  group('Actions', () {
    testWidgets('Create Account opens sign-up, back returns to welcome', (
      tester,
    ) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.tap(_createAccount);
      await tester.pumpAndSettle();
      expect(_currentAuthMode(tester), AuthEntryMode.signUp);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AuthEntryScreen), findsNothing);
      expect(_createAccount, findsOneWidget);
    });

    testWidgets('Log In opens log-in', (tester) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.tap(_logIn);
      await tester.pumpAndSettle();
      expect(_currentAuthMode(tester), AuthEntryMode.logIn);

      // Cross-link between auth entry screens works too.
      await tester.tap(find.text('Create a new account'));
      await tester.pumpAndSettle();
      expect(_currentAuthMode(tester), AuthEntryMode.signUp);
    });

    testWidgets('feature card opens details; Close dismisses it', (
      tester,
    ) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('feature-delivery')));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureDetailSheet), findsOneWidget);
      expect(find.text('Door-to-door pickup and drop-off'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureDetailSheet), findsNothing);
      expect(find.byType(AuthEntryScreen), findsNothing);
    });

    testWidgets('feature sheet "Get started" continues to sign-up', (
      tester,
    ) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('feature-ride')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureDetailSheet), findsNothing);
      expect(_currentAuthMode(tester), AuthEntryMode.signUp);
    });
  });

  group('Onboarding pagination', () {
    testWidgets('swiping advances pages and updates the indicator', (
      tester,
    ) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
      expect(find.text('Fixed Fare'), findsOneWidget);
      expect(find.text('Negotiate'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('Skip jumps to the last page and then hides', (tester) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);
      // Hidden: fully transparent and no longer hit-testable.
      final skip = find.text('Skip');
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: skip, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.opacity, 0);
      expect(skip.hitTestable(), findsNothing);
    });

    testWidgets('tapping a page dot jumps to that page', (tester) async {
      setScreen(tester, _phone);
      await pumpApp(tester);

      await tester.tap(find.bySemanticsLabel('Go to page 2'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
    });
  });

  group('Responsive layout (no overflow)', () {
    const sizes = <String, Size>{
      'small Android 320x568': Size(320, 568),
      'budget Android 360x640': Size(360, 640),
      'iPhone SE 375x667': Size(375, 667),
      'Pixel 7 412x915': Size(412, 915),
      'iPhone 15 393x852': Size(393, 852),
      'iPhone Pro Max 430x932': Size(430, 932),
      'tablet 820x1180': Size(820, 1180),
    };

    for (final entry in sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${entry.key} @ text ${scale}x — all pages', (
          tester,
        ) async {
          setScreen(tester, entry.value, textScale: scale);
          await pumpApp(tester);
          expect(tester.takeException(), isNull);

          for (var page = 2; page <= 3; page++) {
            await tester.tap(find.bySemanticsLabel('Go to page $page'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          // Primary actions stay fully on screen and tappable.
          for (final button in [_createAccount, _logIn]) {
            final rect = tester.getRect(button);
            expect(rect.bottom, lessThanOrEqualTo(entry.value.height));
            expect(rect.height, greaterThanOrEqualTo(48));
          }
        });
      }
    }
  });
}
