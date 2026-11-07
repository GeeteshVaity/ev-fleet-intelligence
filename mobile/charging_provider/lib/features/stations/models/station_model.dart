class Station {
  const Station({
    required this.id,
    required this.stationName,
    this.ownerUserId,
    this.providerType,
    this.accessType,
    this.address,
    this.latitude,
    this.longitude,
    this.connectorType,
    this.powerKw,
    this.pricePerKwh,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String stationName;
  final String? ownerUserId;
  final String? providerType;
  final String? accessType;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? connectorType;
  final double? powerKw;
  final double? pricePerKwh;
  final bool active;
  final DateTime? createdAt;

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      ownerUserId: json['ownerUserId']?.toString(),
      providerType: json['providerType']?.toString(),
      accessType: json['accessType']?.toString(),
      address: json['address']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      connectorType: json['connectorType']?.toString(),
      powerKw: (json['powerKw'] as num?)?.toDouble(),
      pricePerKwh: (json['pricePerKwh'] as num?)?.toDouble(),
      active: json['active'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
    );
  }
}