import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/geo_location.dart';
import '../domain/station.dart';
import '../domain/station_repository.dart';

/// ---------------------------------------------------------------------------
/// DEMO DATA — in-memory sample stations for UI development.
/// This repository never talks to a backend and every screen that renders its
/// data shows a "Demo data" label. It is replaced by [StationRepositoryImpl]
/// as soon as `API_BASE_URL` is configured.
/// ---------------------------------------------------------------------------
abstract final class DemoStations {
  /// Reference point the demo distances are measured from (Berlin centre).
  static const GeoLocation origin = GeoLocation(
    latitude: 52.5200,
    longitude: 13.4050,
    label: 'Berlin, Mitte',
  );

  static const String demoOwnerId = 'demo-owner';

  static List<Station> all() => [
    Station(
      id: 'st-1001',
      name: 'VoltCorner Potsdamer Platz',
      address: 'Alte Potsdamer Straße 7, 10785 Berlin',
      latitude: 52.5096,
      longitude: 13.3760,
      providerType: StationProviderType.business,
      accessType: StationAccessType.open,
      connectorType: ConnectorType.ccs2,
      chargingPowerKw: 150,
      pricePerKwh: 0.49,
      status: AvailabilityStatus.available,
      description:
          'Four rapid chargers under the plaza canopy, lit 24/7 with '
          'payment by app or contactless terminal.',
      accessInstructions:
          'Enter the underground level -1, chargers are in bay A12–A15.',
      amenities: const ['24/7 CCTV', 'Café', 'Restrooms', 'Covered'],
      imageUrls: const [
        'https://picsum.photos/seed/voltcorner/800/500',
        'https://picsum.photos/seed/voltcorner2/800/500',
      ],
      openingHours: 'Mon–Sun 00:00–24:00',
      opensAtHour: 0,
      closesAtHour: 24,
      rating: 4.6,
      ratingCount: 128,
      ownerId: demoOwnerId,
    ),
    Station(
      id: 'st-1002',
      name: 'HomeCharge Kreuzberg',
      address: 'Oranienstraße 168, 10999 Berlin',
      latitude: 52.5017,
      longitude: 13.4217,
      providerType: StationProviderType.household,
      accessType: StationAccessType.gated,
      connectorType: ConnectorType.type2,
      chargingPowerKw: 11,
      pricePerKwh: 0.29,
      status: AvailabilityStatus.available,
      description:
          'A driveway wallbox shared by the household. Quiet street '
          'parking, cable included.',
      accessInstructions:
          'Gate code is shared with your booking confirmation. Please '
          'do not block the garage door.',
      amenities: const ['Cable included', 'Street parking'],
      imageUrls: const ['https://picsum.photos/seed/homecharge/800/500'],
      openingHours: 'Mon–Sun 07:00–22:00',
      opensAtHour: 7,
      closesAtHour: 22,
      // No ratings yet — the UI must not fabricate one.
    ),
    Station(
      id: 'st-1003',
      name: 'CityPark Mitte Garage',
      address: 'Invalidenstraße 117, 10115 Berlin',
      latitude: 52.5323,
      longitude: 13.3816,
      providerType: StationProviderType.public,
      accessType: StationAccessType.app,
      connectorType: ConnectorType.ccs2,
      chargingPowerKw: 50,
      pricePerKwh: 0.41,
      status: AvailabilityStatus.busy,
      description:
          'Municipal garage with two DC chargers on level 0, plus a '
          'ticket machine for parking.',
      accessInstructions: 'Scan the QR code on the charger with the app.',
      amenities: const ['Garage', 'CCTV', 'Parking ticket'],
      imageUrls: const ['https://picsum.photos/seed/citypark/800/500'],
      openingHours: 'Mon–Sun 06:00–23:00',
      opensAtHour: 6,
      closesAtHour: 23,
      rating: 4.1,
      ratingCount: 64,
      ownerId: demoOwnerId,
    ),
    Station(
      id: 'st-1004',
      name: 'ElecHub Ostbahnhof',
      address: 'Friedrichstraße 12, 10117 Berlin',
      latitude: 52.5152,
      longitude: 13.4196,
      providerType: StationProviderType.business,
      accessType: StationAccessType.open,
      connectorType: ConnectorType.ccs2,
      chargingPowerKw: 350,
      pricePerKwh: 0.59,
      status: AvailabilityStatus.available,
      description:
          'Ultra-fast hub with pull-through bays, designed for long-distance '
          'corridors.',
      amenities: const ['24/7', 'Lounge', 'Restrooms', 'Snacks'],
      imageUrls: const ['https://picsum.photos/seed/elichub/800/500'],
      openingHours: 'Mon–Sun 00:00–24:00',
      opensAtHour: 0,
      closesAtHour: 24,
      rating: 4.2,
      ratingCount: 211,
    ),
    Station(
      id: 'st-1005',
      name: 'Garden Plug Charlottenburg',
      address: 'Schillerstraße 22, 10629 Berlin',
      latitude: 52.5115,
      longitude: 13.3245,
      providerType: StationProviderType.household,
      accessType: StationAccessType.residents,
      connectorType: ConnectorType.type2,
      chargingPowerKw: 7.4,
      pricePerKwh: 0.25,
      status: AvailabilityStatus.offline,
      description: 'Garden wallbox of a private home, available to neighbours.',
      accessInstructions: 'Ring the bell at Schillerstraße 22 on arrival.',
      amenities: const ['Garden', 'Cable included'],
      imageUrls: const [],
      openingHours: 'Mon–Fri 18:00–21:00',
      opensAtHour: 18,
      closesAtHour: 21,
      isActive: false,
    ),
    Station(
      id: 'st-1006',
      name: 'AutoStop Schöneberg',
      address: 'Akazienstraße 30, 10827 Berlin',
      latitude: 52.4836,
      longitude: 13.3545,
      providerType: StationProviderType.public,
      accessType: StationAccessType.open,
      connectorType: ConnectorType.type2,
      chargingPowerKw: 22,
      pricePerKwh: 0.35,
      status: AvailabilityStatus.available,
      description:
          'Sidewalk charging pillar next to the market square, '
          'with two Type-2 sockets.',
      amenities: const ['Two sockets', 'Street lighting'],
      imageUrls: const ['https://picsum.photos/seed/autostop/800/500'],
      openingHours: 'Mon–Sun 08:00–22:00',
      opensAtHour: 8,
      closesAtHour: 22,
      rating: 4.8,
      ratingCount: 57,
    ),
    Station(
      id: 'st-1007',
      name: 'NordWatt Fast Charge',
      address: 'Bornholmer Straße 55, 10437 Berlin',
      latitude: 52.5480,
      longitude: 13.3966,
      providerType: StationProviderType.business,
      accessType: StationAccessType.open,
      connectorType: ConnectorType.chademo,
      chargingPowerKw: 100,
      pricePerKwh: 0.45,
      status: AvailabilityStatus.available,
      description: 'Forecourt rapid charger beside the fuel station shop.',
      amenities: const ['Shop', '24/7', 'Toilets'],
      imageUrls: const ['https://picsum.photos/seed/nordwatt/800/500'],
      openingHours: 'Mon–Sun 00:00–24:00',
      opensAtHour: 0,
      closesAtHour: 24,
      rating: 3.9,
      ratingCount: 32,
    ),
  ];
}

/// Development-only in-memory [StationRepository].
class MockStationRepository implements StationRepository {
  MockStationRepository({List<Station>? seed})
    : _stations = seed ?? DemoStations.all();

  final List<Station> _stations;

  Future<void> _delay() => Future<void>.delayed(AppConstants.mockLatency);

  @override
  Future<List<Station>> getStations({
    StationFilter filter = StationFilter.empty,
    GeoLocation? origin,
  }) async {
    await _delay();
    final withDistance =
        _stations
            .where((s) => s.isActive)
            .map((s) => s.withDistanceFrom(origin))
            .where(filter.matches)
            .toList()
          ..sort((a, b) {
            final da = a.distanceMeters;
            final db = b.distanceMeters;
            if (da != null && db != null) return da.compareTo(db);
            return a.name.compareTo(b.name);
          });
    return withDistance;
  }

  @override
  Future<Station> getStation(String id) async {
    await _delay();
    return _stations.firstWhere(
      (s) => s.id == id,
      orElse: () => throw const ValidationException('Station not found'),
    );
  }

  @override
  Future<List<Station>> getMyStations() async {
    await _delay();
    return _stations
        .where((s) => s.ownerId == DemoStations.demoOwnerId)
        .toList();
  }

  @override
  Future<Station> createStation(CreateStationInput input) async {
    await _delay();
    final station = Station(
      id: 'st-${DateTime.now().millisecondsSinceEpoch}',
      name: input.name,
      address: input.address,
      latitude: input.latitude,
      longitude: input.longitude,
      providerType: input.providerType,
      accessType: input.accessType,
      connectorType: input.connectorType,
      chargingPowerKw: input.chargingPowerKw,
      pricePerKwh: input.pricePerKwh,
      description: input.description,
      accessInstructions: input.accessInstructions,
      amenities: input.amenities,
      imageUrls: input.imageUrls,
      openingHours: input.openingHours,
      opensAtHour: input.opensAtHour,
      closesAtHour: input.closesAtHour,
      slotMinutes: input.slotMinutes,
      ownerId: DemoStations.demoOwnerId,
      status: AvailabilityStatus.available,
    );
    _stations.add(station);
    return station;
  }

  @override
  Future<Station> updateStation(String id, CreateStationInput input) async {
    await _delay();
    final index = _stations.indexWhere((s) => s.id == id);
    if (index == -1) {
      throw const ValidationException('Station not found');
    }
    final current = _stations[index];
    final updated = current.copyWith(
      name: input.name,
      address: input.address,
      latitude: input.latitude,
      longitude: input.longitude,
      providerType: input.providerType,
      accessType: input.accessType,
      connectorType: input.connectorType,
      chargingPowerKw: input.chargingPowerKw,
      pricePerKwh: input.pricePerKwh,
      description: input.description,
      accessInstructions: input.accessInstructions,
      amenities: input.amenities,
      imageUrls: input.imageUrls,
      openingHours: input.openingHours,
      opensAtHour: input.opensAtHour,
      closesAtHour: input.closesAtHour,
      slotMinutes: input.slotMinutes,
    );
    _stations[index] = updated;
    return updated;
  }

  @override
  Future<Station> setStationActive(String id, bool active) async {
    await _delay();
    final index = _stations.indexWhere((s) => s.id == id);
    if (index == -1) {
      throw const ValidationException('Station not found');
    }
    _stations[index] = _stations[index].copyWith(isActive: active);
    return _stations[index];
  }
}
