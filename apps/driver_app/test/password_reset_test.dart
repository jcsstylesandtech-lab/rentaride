import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:rent_a_ride_driver/app.dart';
import 'package:rent_a_ride_driver/core/format.dart';
import 'package:rent_a_ride_driver/data/driver_repository.dart';
import 'package:rent_a_ride_driver/screens/forgot_password_screen.dart';
import 'package:rent_a_ride_driver/state/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for Supabase: records calls and signs in when the code is right.
class _FakeRepo extends DriverRepository {
  _FakeRepo(this.session) : super(SupabaseClient('http://localhost', 'test-key'));

  final StreamController<String?> session;
  final calls = <String>[];
  bool failSaveOnce = false;

  @override
  Future<void> sendPasswordResetCode(String email) async => calls.add('send:$email');

  @override
  Future<void> verifyPasswordResetCode({required String email, required String code}) async {
    calls.add('verify:$code');
    if (code != '123456') throw const AuthException('Token has expired or is invalid');
    session.add('driver-1'); // Supabase signs the driver in here
  }

  @override
  Future<void> setNewPassword(String password) async {
    calls.add('save:$password');
    if (failSaveOnce) {
      failSaveOnce = false;
      throw Exception('SocketException: Failed host lookup');
    }
  }
}

void main() {
  late StreamController<String?> session;
  late _FakeRepo repo;

  Future<void> openReset(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    session = StreamController<String?>();
    addTearDown(session.close);
    repo = _FakeRepo(session);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) => session.stream),
        repoProvider.overrideWithValue(repo),
        driverStateProvider.overrideWith((ref) async =>
            const DriverState(profile: null, driver: null, vehicles: [], documents: [])),
      ],
      child: MaterialApp(
        navigatorKey: DriverApp.navigatorKey,
        theme: RarTheme.dark(),
        home: const AppGate(),
      ),
    ));
    session.add(null);
    await tester.pumpAndSettle();
    DriverApp.navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const ForgotPasswordScreen(initialEmail: 'ada@example.com'),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(
        find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText)), text);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('code + new password resets and leaves the driver signed in', (tester) async {
    await openReset(tester);

    await tap(tester, 'reset-send');
    expect(repo.calls, ['send:ada@example.com']);
    expect(find.textContaining('We emailed a code'), findsOneWidget);

    // Wrong code: clear message, still on the reset screen.
    await type(tester, 'reset-code', '000000');
    await type(tester, 'reset-password', 'NewPass99');
    await type(tester, 'reset-confirm', 'NewPass99');
    await tap(tester, 'reset-submit');
    expect(find.text('That code is wrong or has expired. Check it, or send a new code.'), findsOneWidget);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    // Right code: the sign-in it causes must not close the screen before the
    // password is saved; then the screen closes on its own.
    await type(tester, 'reset-code', '123456');
    await tap(tester, 'reset-submit');
    expect(repo.calls, containsAllInOrder(['verify:123456', 'save:NewPass99']));
    expect(find.byType(ForgotPasswordScreen), findsNothing);
    expect(find.text('This is a passenger account'), findsOneWidget); // signed-in gate (fake profile)
  });

  testWidgets('if saving fails after the code is accepted, retry saves without re-checking the code',
      (tester) async {
    await openReset(tester);
    await tap(tester, 'reset-send');
    repo.failSaveOnce = true;

    await type(tester, 'reset-code', '123456');
    await type(tester, 'reset-password', 'NewPass99');
    await type(tester, 'reset-confirm', 'NewPass99');
    await tap(tester, 'reset-submit');
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.textContaining('No internet connection'), findsOneWidget);

    await tap(tester, 'reset-submit');
    expect(repo.calls.where((c) => c.startsWith('verify')).length, 1);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
  });

  testWidgets('mismatched passwords and short codes are caught before sending', (tester) async {
    await openReset(tester);
    await tap(tester, 'reset-send');
    await type(tester, 'reset-code', '12');
    await type(tester, 'reset-password', 'NewPass99');
    await type(tester, 'reset-confirm', 'Other999');
    await tap(tester, 'reset-submit');
    expect(find.text('Enter the code from the email'), findsOneWidget);
    expect(find.text('The passwords do not match'), findsOneWidget);
    expect(repo.calls, ['send:ada@example.com']);
  });

  test('friendly messages for reset errors', () {
    expect(friendlyError(const AuthException('Token has expired or is invalid')),
        'That code is wrong or has expired. Check it, or send a new code.');
    expect(friendlyError(const AuthException('New password should be different from the old password.')),
        'Choose a password different from your old one.');
  });
}
