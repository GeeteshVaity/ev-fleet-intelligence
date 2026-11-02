import 'package:flutter_test/flutter_test.dart';
import 'package:ev_fleet_charging_provider/app/app.dart';

void main() {
  testWidgets('Charging Provider app starts successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChargingProviderApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}