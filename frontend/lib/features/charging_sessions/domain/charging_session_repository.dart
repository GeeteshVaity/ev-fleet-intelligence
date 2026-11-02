import 'charging_session.dart';

/// Contract for charging-history data access.
abstract interface class ChargingSessionRepository {
  /// Completed sessions, newest first (historical records only).
  Future<List<ChargingSession>> getSessions();

  Future<ChargingSession> getSession(String id);
}
