import '../../../shared/models/geo_location.dart';

/// Who operates/owns the station.
enum StationProviderType {
  household('Household'),
  business('Business'),
  public('Public');

  const StationProviderType(this.label);
  final String label;
}

/// How a driver gets access to the charger.
enum StationAccessType {
  open('Open access'),
  residents('Residents only'),
  gated('Gated / key required'),
  app('App or RFID required');

  const StationAccessType(this.label);
  final String label;
}

/// Connector standards supported by the demo dataset and forms.
enum ConnectorType {
  type2('Type 2'),
  ccs2('CCS2'),
  chademo('CHAdeMO'),
  type1('Type 1'),
  nacs('NACS');

  const ConnectorType(this.label);
  final String label;
}

/// Availability shown on cards. Derived from demo data — the Spring Boot
/// backend will be the source of truth once connected.
enum AvailabilityStatus {
  available('Available'),
  busy('In use'),
  offline('Offline'),
  unknown('Unknown');

  const AvailabilityStatus(this.label);
  final String label;
}

/// Charging speed buckets derived from kW output.
enum ChargingTier {
  slow('Slow', 0, 11),
  standard('Standard', 11, 22),
  fast('Fast', 22, 100),
  rapid('Rapid', 100, double.infinity);

  const ChargingTier(this.label, this.minKw, this.maxKw);
  final String label;
  final double minKw;
  final double maxKw;

  static ChargingTier forPower(double kw) => ChargingTier.values.firstWhere(
    (tier) => kw < tier.maxKw,
    orElse: () => ChargingTier.rapid,
  );

  bool contains(double kw) => kw >= minKw && kw < maxKw;
}

/// Immutable charging station entity (domain layer, framework-free).
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.providerType,
    required this.accessType,
    required this.connectorType,
    required this.chargingPowerKw,
    required this.pricePerKwh,
    this.currency = 'EUR',
    this.status = AvailabilityStatus.unknown,
    this.description,
    this.accessInstructions,
    this.amenities = const [],
    this.imageUrls = const [],
    this.openingHours,
    this.opensAtHour,
    this.closesAtHour,
    this.slotMinutes = 60,
    this.rating,
    this.ratingCount,
    this.distanceMeters,
    this.ownerId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final StationProviderType providerType;
  final StationAccessType accessType;
  final ConnectorType connectorType;
  final double chargingPowerKw;
  final double pricePerKwh;
  final String currency;
  final AvailabilityStatus status;

  /// Human description; null when the owner has not provided one.
  final String? description;

  /// How to get to/into the charger (parking, gate code...). Null if absent.
  final String? accessInstructions;

  /// e.g. ['Coffee bar', '24/7 CCTV'].
  final List<String> amenities;

  /// Remote images (S3 in the future). Empty when none were provided.
  final List<String> imageUrls;

  /// Free-text opening hours, e.g. `Mon–Sun 07:00–22:00`. Null if absent.
  final String? openingHours;

  /// Machine-readable hours used by the booking slot generator (nullable).
  final int? opensAtHour;
  final int? closesAtHour;

  /// Length of a bookable slot in minutes.
  final int slotMinutes;

  /// Rating only exists when real ratings exist; null otherwise.
  final double? rating;
  final int? ratingCount;

  /// Straight-line distance from the user's search origin, when known.
  final double? distanceMeters;

  /// Owner identifier (station-owner management).
  final String? ownerId;

  /// Owners can deactivate a station without deleting it.
  final bool isActive;

  ChargingTier get chargingTier => ChargingTier.forPower(chargingPowerKw);

  bool get hasRatings => rating != null && (ratingCount ?? 0) > 0;

  bool get hasImages => imageUrls.isNotEmpty;

  bool get isBookable =>
      isActive && status != AvailabilityStatus.offline && opensAtHour != null;

  Station copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    StationProviderType? providerType,
    StationAccessType? accessType,
    ConnectorType? connectorType,
    double? chargingPowerKw,
    double? pricePerKwh,
    String? currency,
    AvailabilityStatus? status,
    String? description,
    String? accessInstructions,
    List<String>? amenities,
    List<String>? imageUrls,
    String? openingHours,
    int? opensAtHour,
    int? closesAtHour,
    int? slotMinutes,
    double? rating,
    int? ratingCount,
    double? distanceMeters,
    String? ownerId,
    bool? isActive,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      providerType: providerType ?? this.providerType,
      accessType: accessType ?? this.accessType,
      connectorType: connectorType ?? this.connectorType,
      chargingPowerKw: chargingPowerKw ?? this.chargingPowerKw,
      pricePerKwh: pricePerKwh ?? this.pricePerKwh,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      description: description ?? this.description,
      accessInstructions: accessInstructions ?? this.accessInstructions,
      amenities: amenities ?? this.amenities,
      imageUrls: imageUrls ?? this.imageUrls,
      openingHours: openingHours ?? this.openingHours,
      opensAtHour: opensAtHour ?? this.opensAtHour,
      closesAtHour: closesAtHour ?? this.closesAtHour,
      slotMinutes: slotMinutes ?? this.slotMinutes,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      ownerId: ownerId ?? this.ownerId,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Returns a copy with [distanceMeters] recomputed against [origin].
  Station withDistanceFrom(GeoLocation? origin) {
    if (origin == null) return copyWith(distanceMeters: null);
    final meters = GeoLocation.distanceMeters(
      origin,
      GeoLocation(latitude: latitude, longitude: longitude),
    );
    return copyWith(distanceMeters: meters);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'providerType': providerType.name,
    'accessType': accessType.name,
    'connectorType': connectorType.name,
    'chargingPowerKw': chargingPowerKw,
    'pricePerKwh': pricePerKwh,
    'currency': currency,
    'status': status.name,
    'description': description,
    'accessInstructions': accessInstructions,
    'amenities': amenities,
    'imageUrls': imageUrls,
    'openingHours': openingHours,
    'opensAtHour': opensAtHour,
    'closesAtHour': closesAtHour,
    'slotMinutes': slotMinutes,
    'rating': rating,
    'ratingCount': ratingCount,
    'ownerId': ownerId,
    'isActive': isActive,
  };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    id: '${json['id']}',
    name: json['name'] as String? ?? json['stationName'] as String? ?? '',
    address: json['address'] as String? ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    providerType: StationProviderType.values.firstWhere(
      (e) => e.name == json['providerType'].toString().toLowerCase(),
      orElse: () => StationProviderType.business,
    ),
    accessType: StationAccessType.values.firstWhere(
      (e) => e.name == json['accessType'].toString().toLowerCase(),
      orElse: () => StationAccessType.open,
    ),
    connectorType: ConnectorType.values.firstWhere(
      (e) => e.name == json['connectorType'].toString().toLowerCase(),
      orElse: () => ConnectorType.type2,
    ),
    chargingPowerKw:
        (json['chargingPowerKw'] as num? ?? json['powerKw'] as num? ?? 0)
            .toDouble(),
    pricePerKwh: (json['pricePerKwh'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'EUR',
    status: AvailabilityStatus.values.firstWhere(
      (e) => e.name == json['status'].toString().toLowerCase(),
      orElse: () => AvailabilityStatus.unknown,
    ),
    description: json['description'] as String?,
    accessInstructions: json['accessInstructions'] as String?,
    amenities: (json['amenities'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
    imageUrls: (json['imageUrls'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
    openingHours: json['openingHours'] as String?,
    opensAtHour: (json['opensAtHour'] as num?)?.toInt(),
    closesAtHour: (json['closesAtHour'] as num?)?.toInt(),
    slotMinutes: (json['slotMinutes'] as num?)?.toInt() ?? 60,
    rating: (json['rating'] as num?)?.toDouble(),
    ratingCount: (json['ratingCount'] as num?)?.toInt(),
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    ownerId: json['ownerId'] == null ? null : '${json['ownerId']}',
    isActive: json['isActive'] as bool? ?? true,
  );
}

/// Search + filter state for station discovery. Pure and immutable so it can
/// be unit-tested; matching lives here instead of in widgets.
class StationFilter {
  const StationFilter({
    this.query = '',
    this.maxDistanceKm,
    this.connectors = const {},
    this.speedTier,
    this.minPricePerKwh,
    this.maxPricePerKwh,
    this.availableFromHour,
    this.availableToHour,
    this.providerTypes = const {},
  });

  final String query;

  /// Maximum distance in km (null = no limit).
  final double? maxDistanceKm;

  /// Empty = all connector types.
  final Set<ConnectorType> connectors;

  /// null = any charging speed.
  final ChargingTier? speedTier;

  final double? minPricePerKwh;
  final double? maxPricePerKwh;

  /// "Available time" window in hours (0–23), both nullable.
  final int? availableFromHour;
  final int? availableToHour;

  /// Empty = all provider types (household/business/public).
  final Set<StationProviderType> providerTypes;

  int get activeCount {
    var count = 0;
    if (query.trim().isNotEmpty) count++;
    if (maxDistanceKm != null) count++;
    if (connectors.isNotEmpty) count++;
    if (speedTier != null) count++;
    if (minPricePerKwh != null || maxPricePerKwh != null) count++;
    if (availableFromHour != null || availableToHour != null) count++;
    if (providerTypes.isNotEmpty) count++;
    return count;
  }

  bool get isActive => activeCount > 0;

  /// True when [station] satisfies every active constraint.
  bool matches(Station station) {
    final text = query.trim().toLowerCase();
    if (text.isNotEmpty) {
      final haystack =
          '${station.name} ${station.address} ${station.connectorType.label} '
                  '${station.providerType.label}'
              .toLowerCase();
      if (!haystack.contains(text)) return false;
    }

    if (maxDistanceKm != null) {
      final distance = station.distanceMeters;
      if (distance == null || distance > maxDistanceKm! * 1000) return false;
    }

    if (connectors.isNotEmpty && !connectors.contains(station.connectorType)) {
      return false;
    }

    if (speedTier != null && !speedTier!.contains(station.chargingPowerKw)) {
      return false;
    }

    if (minPricePerKwh != null && station.pricePerKwh < minPricePerKwh!) {
      return false;
    }
    if (maxPricePerKwh != null && station.pricePerKwh > maxPricePerKwh!) {
      return false;
    }

    if (providerTypes.isNotEmpty &&
        !providerTypes.contains(station.providerType)) {
      return false;
    }

    final open = station.opensAtHour;
    final close = station.closesAtHour;
    if (availableFromHour != null || availableToHour != null) {
      if (open == null || close == null) return false;
      final from = availableFromHour ?? open;
      final to = availableToHour ?? close;
      if (from >= close || to <= open) return false;
    }

    return true;
  }

  StationFilter copyWith({
    String? query,
    double? maxDistanceKm,
    Set<ConnectorType>? connectors,
    ChargingTier? speedTier,
    double? minPricePerKwh,
    double? maxPricePerKwh,
    int? availableFromHour,
    int? availableToHour,
    Set<StationProviderType>? providerTypes,
    bool clearMaxDistance = false,
    bool clearSpeedTier = false,
    bool clearPriceRange = false,
    bool clearAvailabilityWindow = false,
  }) {
    return StationFilter(
      query: query ?? this.query,
      maxDistanceKm: clearMaxDistance
          ? null
          : (maxDistanceKm ?? this.maxDistanceKm),
      connectors: connectors ?? this.connectors,
      speedTier: clearSpeedTier ? null : (speedTier ?? this.speedTier),
      minPricePerKwh: clearPriceRange
          ? null
          : (minPricePerKwh ?? this.minPricePerKwh),
      maxPricePerKwh: clearPriceRange
          ? null
          : (maxPricePerKwh ?? this.maxPricePerKwh),
      availableFromHour: clearAvailabilityWindow
          ? null
          : (availableFromHour ?? this.availableFromHour),
      availableToHour: clearAvailabilityWindow
          ? null
          : (availableToHour ?? this.availableToHour),
      providerTypes: providerTypes ?? this.providerTypes,
    );
  }

  static const StationFilter empty = StationFilter();
}

/// Payload used by the owner forms to create or edit a station.
class CreateStationInput {
  const CreateStationInput({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.providerType,
    required this.accessType,
    required this.connectorType,
    required this.chargingPowerKw,
    required this.pricePerKwh,
    this.description,
    this.accessInstructions,
    this.amenities = const [],
    this.imageUrls = const [],
    this.openingHours,
    this.opensAtHour,
    this.closesAtHour,
    this.slotMinutes = 60,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final StationProviderType providerType;
  final StationAccessType accessType;
  final ConnectorType connectorType;
  final double chargingPowerKw;
  final double pricePerKwh;
  final String? description;
  final String? accessInstructions;
  final List<String> amenities;
  final List<String> imageUrls;
  final String? openingHours;
  final int? opensAtHour;
  final int? closesAtHour;
  final int slotMinutes;

  Map<String, dynamic> toJson() => {
    'stationName': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'providerType': providerType.name,
    'accessType': accessType.name,
    'connectorType': connectorType.name,
    'powerKw': chargingPowerKw,
    'pricePerKwh': pricePerKwh,
    'description': description,
    'accessInstructions': accessInstructions,
    'amenities': amenities,
    'imageUrls': imageUrls,
    'openingHours': openingHours,
    'opensAtHour': opensAtHour,
    'closesAtHour': closesAtHour,
    'slotMinutes': slotMinutes,
  };
}
