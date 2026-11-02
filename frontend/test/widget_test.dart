import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:evfleet_frontend/app/app.dart';

/// Boots the app with an empty (signed-out) session.
///
/// Tests run without `--dart-define` values, so startup first shows the
/// configuration gate. It is a diagnostic, not a hard block: dismiss it and
/// continue to the authentication flow.
Future<void> _startSignedOut(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const ProviderScope(child: EvFleetApp()));
  await tester.pump(const Duration(seconds: 1));
  final continueButton = find.text('Continue anyway');
  if (continueButton.evaluate().isNotEmpty) {
    await tester.ensureVisible(continueButton);
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pump(const Duration(seconds: 1));
  }
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

void main() {
  testWidgets('uses login first and keeps registration on the back stack', (
    tester,
  ) async {
    await _startSignedOut(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    expect(find.text('How will you use Voltway?'), findsOneWidget);
    await tester.tap(find.text('Vehicle Owner'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Create your Voltway account'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    expect(find.text('How will you use Voltway?'), findsOneWidget);
  });

  testWidgets('signed-out users are redirected to /login from private routes', (
    tester,
  ) async {
    await _startSignedOut(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    // Account setup is only reachable with an authenticated, un-onboarded
    // profile; a deep link must not render the setup form.
    _router(tester).go('/account-setup');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Set up your charger'), findsNothing);
    expect(find.text('Save and continue'), findsNothing);

    // Same for the dashboard routes.
    _router(tester).go('/home');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('verification is a public route and keeps the login fallback', (
    tester,
  ) async {
    await _startSignedOut(tester);

    _router(tester).go('/verify-email?email=driver%40example.com');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Verify and continue'), findsOneWidget);
    expect(
      find.text('Enter the code sent to driver@example.com.'),
      findsOneWidget,
    );
  });
}
