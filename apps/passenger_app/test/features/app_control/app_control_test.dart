import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_passenger/features/app_control/app_control.dart';

void main() {
  Future<StreamController<List<AppNotification>>> pump(WidgetTester tester, AppSettings settings) async {
    final notes = StreamController<List<AppNotification>>();
    addTearDown(notes.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        notificationsProvider.overrideWith((ref) => notes.stream),
      ],
      child: MaterialApp(
        theme: RarTheme.light(),
        builder: (context, child) => AppControlShell(child: child!),
        home: const Scaffold(body: Center(child: Text('Home screen'))),
      ),
    ));
    await tester.pump();
    return notes;
  }

  test('reads the passenger switches from the settings row', () {
    final s = AppSettings.fromRow({
      'rides_enabled': true, 'dispatch_enabled': false, 'delivery_enabled': false,
      'passenger_maintenance': false, 'driver_maintenance': true,
      'maintenance_message': 'Back at 6pm', 'passenger_announcement': '  ', 'driver_announcement': 'Drivers only',
    });
    expect(s.maintenance, isFalse); // the driver app's switch doesn't affect passengers
    expect(s.anyDeliveryEnabled, isFalse);
    expect(s.serviceEnabled('ride'), isTrue);
    expect(s.announcement, isNull); // blank means no banner
  });

  testWidgets('maintenance replaces every screen with the message', (tester) async {
    await pump(tester, const AppSettings(maintenance: true, maintenanceMessage: 'Back at 6pm'));
    expect(find.text('Back soon'), findsOneWidget);
    expect(find.text('Back at 6pm'), findsOneWidget);
    expect(find.text('Home screen'), findsNothing);
  });

  testWidgets('announcement shows above the app and can be hidden', (tester) async {
    await pump(tester, const AppSettings(announcement: '10% off this weekend'));
    expect(find.text('10% off this weekend'), findsOneWidget);
    expect(find.text('Home screen'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide announcement'));
    await tester.pump();
    expect(find.text('10% off this weekend'), findsNothing);
  });

  testWidgets('a new notification pops up; old ones do not', (tester) async {
    final notes = await pump(tester, const AppSettings());
    notes.add([
      AppNotification(id: 'old', title: 'Old news', body: '', read: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1))),
    ]);
    await tester.pump();
    expect(find.text('Old news'), findsNothing);

    notes.add([
      AppNotification(id: 'new', title: 'Your driver is on the way', body: 'Tap to follow', read: false,
          createdAt: DateTime.now()),
    ]);
    await tester.pump();
    expect(find.text('Your driver is on the way'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Your driver is on the way'), findsNothing);
  });
}
