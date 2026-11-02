/// Kinds of in-app notifications.
enum NotificationType {
  booking('Booking'),
  system('System'),
  offer('Offer');

  const NotificationType(this.label);
  final String label;
}

/// Immutable in-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    type: type,
    isRead: isRead ?? this.isRead,
  );
}

/// Contract for notification data access.
abstract interface class NotificationRepository {
  Future<List<AppNotification>> getNotifications();

  /// Returns the updated list after marking everything as read.
  Future<List<AppNotification>> markAllRead();
}
