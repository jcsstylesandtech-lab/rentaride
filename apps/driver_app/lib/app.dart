import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';

import 'core/config.dart';
import 'core/format.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_control.dart';
import 'state/providers.dart';
import 'widgets/common.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  /// Lets the gate close pages opened on top of it (sign-in, settings…)
  /// when the driver signs in or out.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Rent A Ride Driver',
      debugShowCheckedModeBanner: false,
      theme: RarTheme.dark(),
      // Maintenance, announcements and notification pop-ups from the dashboard.
      builder: (context, child) => AppControlShell(child: child!),
      home: AppConfig.isConfigured ? const AppGate() : const _NotConfigured(),
    );
  }
}

/// Signed out → sign in. Not yet approved → onboarding. Approved → drive.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sign-in opens on top of the intro page. When the session changes, close
    // everything above the gate so the driver sees the right screen at once.
    // A password reset signs the driver in partway through; its screen
    // closes itself once the new password is saved.
    ref.listen(sessionProvider, (prev, next) {
      if (ref.read(passwordResetInProgressProvider)) return;
      if (prev?.value != next.value) {
        DriverApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
    final session = ref.watch(sessionProvider);
    if (session.isLoading && !session.hasValue) return const LoadingScreen();
    if (session.value == null) return const IntroScreen();

    final state = ref.watch(driverStateProvider);
    return state.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingScreen(),
      error: (e, _) => MessageScreen(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load your account",
        body: friendlyError(e),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(driverStateProvider),
      ),
      data: (s) {
        if (!s.isDriverAccount) {
          return MessageScreen(
            icon: Icons.person_off_rounded,
            title: 'This is a passenger account',
            body: 'Sign in with a driver account, or create a new one with a different email.',
            actionLabel: 'Sign out',
            onAction: () => ref.read(repoProvider).signOut(),
          );
        }
        return s.approved ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) => const MessageScreen(
        icon: Icons.settings_rounded,
        title: 'App not configured',
        body: 'Run with --dart-define-from-file=env/dev.json (copy env/dev.example.json and add the Supabase URL and publishable key).',
      );
}
