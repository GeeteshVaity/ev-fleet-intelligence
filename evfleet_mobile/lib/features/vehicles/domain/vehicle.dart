import '../../stations/domain/station.dart';

/// Broad vehicle categories supported by the add/edit form.
enum VehicleType {
  car('Car'),
  suv('SUV'),
  van('Van'),
  motorcycle('Motorcycle'),
  other('Other');

  const VehicleType(this.label);
  final String label;
}

/// Immutable vehicle entity owned by a driver.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.type,
    required this.batteryCapacityKwh,
    required this.connectorType,
    this.registrationNumber,
    this.nickname,
  });

  final String id;
  final String brand;
  final String model;
  final VehicleType type;

  /// Optional — many drivers never add a plate.
  final String? registrationNumber;
  final double batteryCapacityKwh;
  final ConnectorType connectorType;
  final String? nickname;

  String get label => '$brand $model';

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    VehicleType? type,
    String? registrationNumber,
    double? batteryCapacityKwh,
    ConnectorType? connectorType,
    String? nickname,
    bool clearRegistration = false,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      type: type ?? this.type,
      registrationNumber: clearRegistration
          ? null
          : (registrationNumber ?? this.registrationNumber),
      batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
      connectorType: connectorType ?? this.connectorType,
      nickname: nickname ?? this.nickname,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'model': model,
    'vehicleType': type.name.toUpperCase(),
    'registrationNumber': registrationNumber,
    'batteryCapacityKwh': batteryCapacityKwh,
    'connectorType': connectorType.name,
    'nickname': nickname,
  };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: '${json['id']}',
    brand: json['brand'] as String? ?? '',
    model: json['model'] as String? ?? '',
    type: VehicleType.values.firstWhere(
      (e) =>
          e.name ==
          (json['type'] ?? json['vehicleType']).toString().toLowerCase(),
      orElse: () => VehicleType.car,
    ),
    registrationNumber: json['registrationNumber'] as String?,
    batteryCapacityKwh: (json['batteryCapacityKwh'] as num?)?.toDouble() ?? 0,
    connectorType: ConnectorType.values.firstWhere(
      (e) => e.name == json['connectorType'],
      orElse: () => ConnectorType.type2,
    ),
    nickname: json['nickname'] as String?,
  );
}
