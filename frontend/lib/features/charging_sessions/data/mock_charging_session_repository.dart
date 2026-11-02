import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../stations/domain/station.dart';
import '../domain/charging_session.dart';
import '../domain/charging_session_repository.dart';

/// ---------------------------------------------------------------------------
/// DEMO DATA — historical charging records for UI development.
/// Records only; the app does not fake any live charging status.
/// ---------------------------------------------------------------------------
abstract final class DemoChargingSessions {
  static List<ChargingSession> all() {
    final today = DateTime.now();
    DateTime day(int offset) => DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: offset));

    return [
      ChargingSession(
        id: 'cs-9001',
        stationId: 'st-1001',
        stationName: 'VoltCorner Potsdamer Platz',
        stationAddress: 'Alte Potsdamer Straße 7, 10785 Berlin',
        startedAt: day(-6).add(const Duration(hours: 14)),
        endedAt: day(-6).add(const Duration(hours: 15, minutes: 18)),
        energyKwh: 42.6,
        connectorType: ConnectorType.ccs2,
        vehicleLabel: 'Tesla Model 3',
        cost: 20.87,
        socFromPercent: 24,
        socToPercent: 86,
      ),
      ChargingSession(
        id: 'cs-9002',
        stationId: 'st-1006',
        stationName: 'AutoStop Schöneberg',
        stationAddress: 'Akazienstraße 30, 10827 Berlin',
        startedAt: day(-11).add(const Duration(hours: 9, minutes: 30)),
        endedAt: day(-11).add(const Duration(hours: 10, minutes: 15)),
        energyKwh: 18.6,
        connectorType: ConnectorType.type2,
        vehicleLabel: 'Tesla Model 3',
        cost: 6.51,
        socFromPercent: 48,
        socToPercent: 72,
      ),
      ChargingSession(
        id: 'cs-9003',
        stationId: 'st-1004',
        stationName: 'ElecHub Ostbahnhof',
        stationAddress: 'Friedrichstraße 12, 10117 Berlin',
        startedAt: day(-19).add(const Duration(hours: 17)),
        endedAt: day(-19).add(const Duration(hours: 17, minutes: 34)),
        energyKwh: 31.2,
        connectorType: ConnectorType.ccs2,
        vehicleLabel: 'Volkswagen ID.4',
        cost: 18.41,
        socFromPercent: 31,
        socToPercent: 71,
      ),
      ChargingSession(
        id: 'cs-9004',
        stationId: 'st-1003',
        stationName: 'CityPark Mitte Garage',
        stationAddress: 'Invalidenstraße 117, 10115 Berlin',
        startedAt: day(-27).add(const Duration(hours: 12)),
        endedAt: day(-27).add(const Duration(hours: 13, minutes: 20)),
        energyKwh: 26.4,
        connectorType: ConnectorType.ccs2,
        vehicleLabel: 'Volkswagen ID.4',
        // Cost not settled for this record — the UI must show it as unknown.
        socFromPercent: 40,
        socToPercent: 78,
      ),
    ];
  }
}

/// Development-only in-memory [ChargingSessionRepository].
class MockChargingSessionRepository implements ChargingSessionRepository {
  MockChargingSessionRepository({List<ChargingSession>? seed})
    : _sessions = seed ?? DemoChargingSessions.all();

  final List<ChargingSession> _sessions;

  @override
  Future<List<ChargingSession>> getSessions() async {
    await Future<void>.delayed(AppConstants.mockLatency);
    return List<ChargingSession>.of(_sessions)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<ChargingSession> getSession(String id) async {
    await Future<void>.delayed(AppConstants.mockLatency);
    return _sessions.firstWhere(
      (s) => s.id == id,
      orElse: () =>
          throw const ValidationException('Charging session not found'),
    );
  }
}

/// DI: demo charging history until `API_BASE_URL` is configured.
final chargingSessionRepositoryProvider = Provider<ChargingSessionRepository>((
  ref,
) {
  return MockChargingSessionRepository();
});
