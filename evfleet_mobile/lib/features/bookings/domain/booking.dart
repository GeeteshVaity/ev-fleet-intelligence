/// Lifecycle of a booking. The backend is always the final authority on
/// availability and on whether a cancellation is allowed.
enum BookingStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  rejected('Rejected'),
  cancelled('Cancelled'),
  completed('Completed');

  const BookingStatus(this.label);
  final String label;

  bool get isCancelledLike =>
      this == BookingStatus.cancelled || this == BookingStatus.rejected;

  bool get isActive =>
      this == BookingStatus.pending || this == BookingStatus.confirmed;
}

/// Immutable booking entity.
class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    this.estimatedEnergyKwh,
    this.estimatedCost,
    this.currency = 'EUR',
    this.cancelledAt,
    this.cancellationReason,
  });

  final String id;

  /// Human reference shown to drivers, e.g. `EV-4821`.
  final String reference;
  final String stationId;
  final String stationName;
  final String stationAddress;
  final String vehicleId;
  final String vehicleLabel;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final DateTime createdAt;

  /// Estimates are only present when the assumptions were provided.
  final double? estimatedEnergyKwh;
  final double? estimatedCost;
  final String? currency;

  final DateTime? cancelledAt;
  final String? cancellationReason;

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  /// True while the slot lies in the future and the booking is still active.
  bool get isUpcoming => endTime.isAfter(DateTime.now()) && status.isActive;

  /// UI hint only — the backend re-checks authorization before cancelling.
  bool get canRequestCancellation =>
      (status == BookingStatus.pending || status == BookingStatus.confirmed) &&
      endTime.isAfter(DateTime.now());

  Booking copyWith({
    String? id,
    String? reference,
    String? stationId,
    String? stationName,
    String? stationAddress,
    String? vehicleId,
    String? vehicleLabel,
    DateTime? startTime,
    DateTime? endTime,
    BookingStatus? status,
    DateTime? createdAt,
    double? estimatedEnergyKwh,
    double? estimatedCost,
    String? currency,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) {
    return Booking(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      stationAddress: stationAddress ?? this.stationAddress,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      estimatedEnergyKwh: estimatedEnergyKwh ?? this.estimatedEnergyKwh,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      currency: currency ?? this.currency,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'stationId': stationId,
    'stationName': stationName,
    'stationAddress': stationAddress,
    'vehicleId': vehicleId,
    'vehicleLabel': vehicleLabel,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'estimatedEnergyKwh': estimatedEnergyKwh,
    'estimatedCost': estimatedCost,
    'currency': currency,
    'cancelledAt': cancelledAt?.toIso8601String(),
    'cancellationReason': cancellationReason,
  };

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: '${json['id']}',
    reference: json['reference'] as String? ?? 'EV-${json['id']}',
    stationId: '${json['stationId']}',
    stationName: json['stationName'] as String? ?? '',
    stationAddress: json['stationAddress'] as String? ?? '',
    vehicleId: '${json['vehicleId']}',
    vehicleLabel: json['vehicleLabel'] as String? ?? '',
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    status: BookingStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => BookingStatus.pending,
    ),
    createdAt: DateTime.parse(
      json['createdAt'] as String? ?? json['startTime'] as String,
    ),
    estimatedEnergyKwh: (json['estimatedEnergyKwh'] as num?)?.toDouble(),
    estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
    currency: json['currency'] as String? ?? 'EUR',
    cancelledAt: json['cancelledAt'] == null
        ? null
        : DateTime.parse(json['cancelledAt'] as String),
    cancellationReason: json['cancellationReason'] as String?,
  );
}

/// Data needed to create a booking. Availability conflicts are ultimately
/// checked by the backend; the mock repository mirrors that behaviour locally
/// so the UI cannot pretend a conflicting booking succeeded.
class CreateBookingInput {
  const CreateBookingInput({
    required this.stationId,
    required this.vehicleId,
    required this.startTime,
    required this.endTime,
    this.estimatedEnergyKwh,
    this.estimatedCost,
  });

  final String stationId;
  final String vehicleId;
  final DateTime startTime;
  final DateTime endTime;
  final double? estimatedEnergyKwh;
  final double? estimatedCost;
}
