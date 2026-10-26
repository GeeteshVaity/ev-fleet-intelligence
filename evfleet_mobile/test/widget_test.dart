import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:evfleet_mobile/app/app.dart';

void main() {
  testWidgets('uses login first and keeps registration on the back stack', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: EvFleetApp()));
    await tester.pump(const Duration(seconds: 1));
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
}
