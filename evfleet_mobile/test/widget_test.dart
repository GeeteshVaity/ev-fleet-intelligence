import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:evfleet_mobile/app/app.dart';

void main() {
  testWidgets('opens the demo home dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EvFleetApp()));
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Jordan'), findsOneWidget);
    expect(find.text('Find your next charge'), findsOneWidget);
  });
}
