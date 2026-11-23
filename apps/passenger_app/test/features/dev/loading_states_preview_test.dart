import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_passenger/app/app.dart';
import 'package:rent_a_ride_passenger/app/router/app_router.dart';
import 'package:rent_a_ride_passenger/app/router/app_routes.dart';

import '../../helpers/test_app.dart';

void main() {
  setUpAll(loadBrandFonts);

  testWidgets('dev route shows skeletons, then content after loading', (
    tester,
  ) async {
    setScreen(tester, const Size(390, 844));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RentARideApp(),
      ),
    );
    container.read(appRouterProvider).go(AppRoutes.devLoadingStates);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Loading states'), findsOneWidget);
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.text('Ibrahim Musa'), findsNothing);

    // Turn loading off → real content cross-fades in.
    await tester.tap(find.widgetWithText(FilterChip, 'Loading'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ibrahim Musa'), findsOneWidget);
    expect(find.byType(SkeletonList), findsNothing);

    // "Simulate network" shows skeletons again, then content.
    await tester.tap(find.text('Simulate network'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SkeletonList), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ibrahim Musa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
