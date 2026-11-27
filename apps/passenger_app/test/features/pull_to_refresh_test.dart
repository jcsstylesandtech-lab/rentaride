import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rent_a_ride_passenger/features/home/presentation/widgets/account_tabs.dart';

void main() {
  Widget host(TabPage page) => MaterialApp(home: Scaffold(body: page));

  testWidgets('pulling a short tab page down runs onRefresh', (t) async {
    var refreshed = 0;
    await t.pumpWidget(host(TabPage(
      title: 'Wallet',
      onRefresh: () async => refreshed++,
      children: const [Text('Balance')],
    )));
    await t.fling(find.text('Balance'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(refreshed, 1);
  });

  testWidgets('a failing refresh stops the spinner without crashing', (t) async {
    await t.pumpWidget(host(TabPage(
      title: 'Rides',
      onRefresh: () async => throw Exception('offline'),
      children: const [Text('No rides yet')],
    )));
    await t.fling(find.text('No rides yet'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('pages without onRefresh have no pull-down', (t) async {
    await t.pumpWidget(host(const TabPage(title: 'Profile', children: [Text('x')])));
    expect(find.byType(RefreshIndicator), findsNothing);
  });
}
