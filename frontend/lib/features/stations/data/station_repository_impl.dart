import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/geo_location.dart';
import '../domain/station.dart';
import '../domain/station_repository.dart';
import 'mock_station_repository.dart';
import 'station_remote_data_source.dart';

/// Repository used when a backend URL is configured: talks to the Spring Boot
/// REST API through [StationRemoteDataSource] and computes distances locally.
///
/// Selected by `stationRepositoryProvider` only when
/// `--dart-define=API_BASE_URL=...` is provided.
class StationRepositoryImpl implements StationRepository {
  StationRepositoryImpl(this._remote);

  final StationRemoteDataSource _remote;

  @override
  Future<List<Station>> getStations({
    StationFilter filter = StationFilter.empty,
    GeoLocation? origin,
  }) async {
    final stations = await _remote.fetchStations(
      query: {
        if (filter.query.trim().isNotEmpty) 'q': filter.query.trim(),
        if (filter.maxDistanceKm != null) 'maxDistanceKm': filter.maxDistanceKm,
        if (filter.connectors.isNotEmpty)
          'connectors': filter.connectors.map((c) => c.name).join(','),
        if (filter.speedTier != null) 'minPowerKw': filter.speedTier!.minKw,
        if (filter.minPricePerKwh != null)
          'minPricePerKwh': filter.minPricePerKwh,
        if (filter.maxPricePerKwh != null)
          'maxPricePerKwh': filter.maxPricePerKwh,
        if (filter.providerTypes.isNotEmpty)
          'providerTypes': filter.providerTypes.map((p) => p.name).join(','),
        if (origin != null) ...{
          'lat': origin.latitude,
          'lng': origin.longitude,
        },
      },
    );

    return stations
        .map((s) => s.withDistanceFrom(origin))
        .where(filter.matches)
        .toList()
      ..sort((a, b) {
        final da = a.distanceMeters;
        final db = b.distanceMeters;
        if (da != null && db != null) return da.compareTo(db);
        return a.name.compareTo(b.name);
      });
  }

  @override
  Future<Station> getStation(String id) => _remote.fetchStation(id);

  @override
  Future<List<Station>> getMyStations() => _remote.fetchStations();

  @override
  Future<Station> createStation(CreateStationInput input) =>
      _remote.createStation(input);

  @override
  Future<Station> updateStation(String id, CreateStationInput input) =>
      _remote.updateStation(id, input);

  @override
  Future<Station> setStationActive(String id, bool active) =>
      _remote.setActive(id, active);
}

/// DI: mock repository while `API_BASE_URL` is unset (demo mode),
/// Spring Boot implementation as soon as it is configured.
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  if (ApiConstants.isMockBackend) return MockStationRepository();
  final remote = StationRemoteDataSource(ref.watch(dioClientProvider));
  return StationRepositoryImpl(remote);
});
