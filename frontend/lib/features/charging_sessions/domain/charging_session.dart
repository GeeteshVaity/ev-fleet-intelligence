import '../../stations/domain/station.dart';

/// A **historical** charging record. The app intentionally has no "live
/// charging status" model yet — live telemetry will come from the backend
/// later, and historical records are clearly separated from it.
class ChargingSession {
  const ChargingSession({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
    required this.startedAt,
    required this.endedAt,
    required this.energyKwh,
    required this.connectorType,
    this.vehicleLabel,
    this.cost,
    this.currency = 'EUR',
    this.socFromPercent,
    this.socToPercent,
  });

  final String id;
  final String stationId;
  final String stationName;
  final String stationAddress;
  final DateTime startedAt;
  final DateTime endedAt;
  final double energyKwh;
  final ConnectorType connectorType;
  final String? vehicleLabel;

  /// Final cost — null when it was not provided/settled yet.
  final double? cost;
  final String? currency;

  /// State-of-charge before/after, when the charger reported it.
  final int? socFromPercent;
  final int? socToPercent;

  int get durationMinutes =>
      endedAt.difference(startedAt).inMinutes.clamp(0, 1 << 30);

  ChargingSession copyWith({
    String? id,
    String? stationId,
    String? stationName,
    String? stationAddress,
    DateTime? startedAt,
    DateTime? endedAt,
    double? energyKwh,
    ConnectorType? connectorType,
    String? vehicleLabel,
    double? cost,
    String? currency,
    int? socFromPercent,
    int? socToPercent,
  }) {
    return ChargingSession(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      stationAddress: stationAddress ?? this.stationAddress,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      energyKwh: energyKwh ?? this.energyKwh,
      connectorType: connectorType ?? this.connectorType,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      socFromPercent: socFromPercent ?? this.socFromPercent,
      socToPercent: socToPercent ?? this.socToPercent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'stationId': stationId,
    'stationName': stationName,
    'stationAddress': stationAddress,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'energyKwh': energyKwh,
    'connectorType': connectorType.name,
    'vehicleLabel': vehicleLabel,
    'cost': cost,
    'currency': currency,
    'socFromPercent': socFromPercent,
    'socToPercent': socToPercent,
  };

  factory ChargingSession.fromJson(Map<String, dynamic> json) =>
      ChargingSession(
        id: json['id'] as String,
        stationId: json['stationId'] as String,
        stationName: json['stationName'] as String? ?? '',
        stationAddress: json['stationAddress'] as String? ?? '',
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        energyKwh: (json['energyKwh'] as num).toDouble(),
        connectorType: ConnectorType.values.firstWhere(
          (e) => e.name == json['connectorType'],
          orElse: () => ConnectorType.type2,
        ),
        vehicleLabel: json['vehicleLabel'] as String?,
        cost: (json['cost'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
        socFromPercent: (json['socFromPercent'] as num?)?.toInt(),
        socToPercent: (json['socToPercent'] as num?)?.toInt(),
      );
}
