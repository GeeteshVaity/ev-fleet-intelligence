import '../../../shared/models/geo_location.dart';
import 'station.dart';

/// Contract for station data access.
///
/// The UI only ever talks to this interface, so the mock implementation used
/// during UI development can be replaced by the Spring Boot implementation
/// (`StationRepositoryImpl`) without touching a single widget.
abstract interface class StationRepository {
  /// All stations matching [filter], sorted by distance when [origin] is set.
  Future<List<Station>> getStations({
    StationFilter filter = StationFilter.empty,
    GeoLocation? origin,
  });

  /// A single station or a [NotFoundException]-style failure.
  Future<Station> getStation(String id);

  /// Stations owned by the signed-in user (station-owner management).
  Future<List<Station>> getMyStations();

  /// Owner creates a new listing.
  Future<Station> createStation(CreateStationInput input);

  /// Owner edits an existing listing (also used to update availability).
  Future<Station> updateStation(String id, CreateStationInput input);

  /// Owner activates/deactivates a listing where supported.
  Future<Station> setStationActive(String id, bool active);
}
