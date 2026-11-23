import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../widgets/common.dart';
import 'account_tab.dart';
import 'drive_tab.dart';
import 'earnings_tab.dart';

/// Approved drivers: Drive, Earnings, Account.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return DriverScaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: RarColors.navy950,
        indicatorColor: RarColors.royal.withValues(alpha: 0.35),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car_rounded), label: 'Drive'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
      // Drive stays alive in the background so location keeps updating.
      child: IndexedStack(index: _tab, children: const [DriveTab(), EarningsTab(), AccountTab()]),
    );
  }
}
