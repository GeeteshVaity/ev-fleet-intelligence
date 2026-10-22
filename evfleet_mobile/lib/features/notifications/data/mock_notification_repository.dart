import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_notification.dart';

/// ---------------------------------------------------------------------------
/// DEMO DATA — sample notifications for UI development.
/// ---------------------------------------------------------------------------
abstract final class DemoNotifications {
  static List<AppNotification> all() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'nt-1',
        title: 'Booking confirmed',
        body:
            'Your slot at VoltCorner Potsdamer Platz is confirmed for '
            'tomorrow at 09:00.',
        createdAt: now.subtract(const Duration(hours: 3)),
        type: NotificationType.booking,
        isRead: true,
      ),
      AppNotification(
        id: 'nt-2',
        title: 'Booking pending review',
        body: 'ElecHub Ostbahnhof will confirm your request shortly.',
        createdAt: now.subtract(const Duration(hours: 6)),
        type: NotificationType.booking,
      ),
      AppNotification(
        id: 'nt-3',
        title: 'Charging receipt available',
        body:
            'Your session at AutoStop Schöneberg is settled: €6.51 for '
            '18.6 kWh.',
        createdAt: now.subtract(const Duration(days: 5)),
        type: NotificationType.system,
      ),
      AppNotification(
        id: 'nt-4',
        title: 'New rapid charger nearby',
        body: 'NordWatt Fast Charge opened 1.4 km from your usual area.',
        createdAt: now.subtract(const Duration(days: 8)),
        type: NotificationType.offer,
      ),
    ];
  }
}

/// Development-only in-memory [NotificationRepository].
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({List<AppNotification>? seed})
    : _notifications = seed ?? DemoNotifications.all();

  final List<AppNotification> _notifications;

  @override
  Future<List<AppNotification>> getNotifications() async {
    await Future<void>.delayed(AppConstants.mockLatency);
    return List<AppNotification>.of(_notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<AppNotification>> markAllRead() async {
    await Future<void>.delayed(AppConstants.mockLatency);
    final updated = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _notifications
      ..clear()
      ..addAll(updated);
    return List<AppNotification>.of(updated);
  }
}

/// DI: demo notifications until `API_BASE_URL` is configured.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository();
});
