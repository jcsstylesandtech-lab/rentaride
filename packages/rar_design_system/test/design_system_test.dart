import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';

Widget _host(Widget child, {bool blur = true}) => MaterialApp(
  theme: RarTheme.dark(),
  home: RarGlassSettings(
    blurEnabled: blur,
    child: Scaffold(
      body: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  ),
);

void main() {
  group('tokens', () {
    test('brand colours match the reference palette', () {
      expect(RarColors.navy, const Color(0xFF061B49));
      expect(RarColors.royal, const Color(0xFF0866FF));
      expect(RarColors.cyan, const Color(0xFF00C8FF));
      expect(RarColors.white, const Color(0xFFFFFFFF));
    });

    test('themes use bundled Poppins and brand colours', () {
      for (final theme in [RarTheme.light(), RarTheme.dark()]) {
        expect(theme.colorScheme.primary, RarColors.royal);
        expect(theme.colorScheme.secondary, RarColors.cyan);
        expect(
          theme.textTheme.bodyMedium!.fontFamily,
          'packages/rar_design_system/Poppins',
        );
      }
      expect(RarTheme.dark().scaffoldBackgroundColor, RarColors.navy);
    });

    test('height classes', () {
      expect(RarResponsive.heightClassOf(568), RarHeightClass.compact);
      expect(RarResponsive.heightClassOf(700), RarHeightClass.regular);
      expect(RarResponsive.heightClassOf(844), RarHeightClass.tall);
    });
  });

  group('RarButton', () {
    testWidgets('invokes onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          RarButton.primary(label: 'Create Account', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('does nothing while loading and shows a spinner', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          RarButton.glass(
            label: 'Log In',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(RarButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('disabled button is announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const RarButton.outline(label: 'Continue', onPressed: null)),
      );
      final node = tester.getSemantics(find.byType(RarButton));
      expect(node.label, 'Continue');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('meets minimum touch target height', (tester) async {
      await tester.pumpWidget(
        _host(RarButton.primary(label: 'Go', onPressed: () {})),
      );
      expect(
        tester.getSize(find.byType(RarButton)).height,
        greaterThanOrEqualTo(RarSpacing.minTouchTarget),
      );
    });
  });

  group('components', () {
    testWidgets('FeatureTile is tappable and hides subtitle when compact', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 170,
            child: FeatureTile(
              icon: Icons.directions_car_rounded,
              title: 'Ride',
              subtitle: 'Get to your destination',
              compact: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Get to your destination'), findsNothing);
      await tester.tap(find.text('Ride'));
      expect(taps, 1);
    });

    testWidgets('PageDots reports position and jumps on tap', (tester) async {
      final handle = tester.ensureSemantics();
      int? tapped;
      await tester.pumpWidget(
        _host(PageDots(count: 3, index: 0, onDotTap: (i) => tapped = i)),
      );
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Go to page 3'));
      expect(tapped, 2);
      handle.dispose();
    });

    testWidgets('GlassContainer renders with and without blur', (tester) async {
      for (final blur in [true, false]) {
        await tester.pumpWidget(
          _host(const GlassContainer(child: Text('glass')), blur: blur),
        );
        expect(find.text('glass'), findsOneWidget);
        expect(
          find.byType(BackdropFilter),
          blur ? findsOneWidget : findsNothing,
        );
      }
    });

    testWidgets('logo and wordmark render without errors', (tester) async {
      await tester.pumpWidget(
        _host(const RarWordmark(subtitle: 'Ride · Deliver · Explore')),
      );
      expect(find.byType(RarLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
