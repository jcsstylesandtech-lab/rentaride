import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../messages/messages.dart';
import '../../../messages/messages_tab.dart';
import '../../../profile/profile_tab.dart';
import '../widgets/account_tabs.dart';
import '../widgets/home_tab.dart';

/// Signed-in shell: Home (map), Rides, Messages, Wallet and Profile.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _home = 0, _profile = 4;

  /// Developer shortcut: `--dart-define=DEMO_START_TAB=2` opens Messages.
  static const _startTab = int.fromEnvironment('DEMO_START_TAB');
  int _tab = _startTab.clamp(0, 4);

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadMessagesProvider);

    Widget icon(IconData data, {bool selected = false, int badge = 0}) {
      final i = Icon(data, color: selected ? RarColors.royal : null);
      return badge == 0
          ? i
          : Badge(
              label: Text('$badge'),
              backgroundColor: RarColors.danger,
              child: i,
            );
    }

    return Theme(
      data: RarTheme.light(),
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            HomeTab(onOpenProfile: () => _goTo(_profile)),
            RidesTab(onBookRide: () => _goTo(_home)),
            const MessagesTab(),
            const WalletTab(),
            const ProfileTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _goTo,
          backgroundColor: RarColors.white,
          indicatorColor: RarColors.surfaceLight,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => RarTypography.caption.copyWith(
              fontSize: 11.5,
              color: s.contains(WidgetState.selected)
                  ? RarColors.royal
                  : RarColors.textSecondary,
            ),
          ),
          destinations: [
            NavigationDestination(
              icon: icon(Icons.home_outlined),
              selectedIcon: icon(Icons.home_rounded, selected: true),
              label: 'Home',
            ),
            NavigationDestination(
              icon: icon(Icons.directions_car_outlined),
              selectedIcon: icon(Icons.directions_car_rounded, selected: true),
              label: 'Rides',
            ),
            NavigationDestination(
              icon: icon(Icons.chat_bubble_outline_rounded, badge: unread),
              selectedIcon: icon(
                Icons.chat_bubble_rounded,
                selected: true,
                badge: unread,
              ),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: icon(Icons.account_balance_wallet_outlined),
              selectedIcon: icon(
                Icons.account_balance_wallet_rounded,
                selected: true,
              ),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: icon(Icons.person_outline_rounded),
              selectedIcon: icon(Icons.person_rounded, selected: true),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
