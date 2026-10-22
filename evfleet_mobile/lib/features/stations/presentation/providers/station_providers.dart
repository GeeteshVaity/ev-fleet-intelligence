import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../shared/models/geo_location.dart';
import '../../data/station_repository_impl.dart';
import '../../domain/station.dart';

/// Where the user is searching from. Defaults to the demo origin so the UI
/// shows distances out of the box; device location or a manual search
/// replaces it.
class UserLocationState {
  const UserLocationState({
    this.location = AppConstants.demoOrigin,
    this.isLoading = false,
    this.isManual = false,
    this.notice,
  });

  final GeoLocation? location;
  final bool isLoading;

  /// True when the user picked/typed the location instead of GPS.
  final bool isManual;

  /// Explanation shown when GPS could not be used (permission denied, ...).
  final String? notice;

  bool get usingFallback => location == AppConstants.demoOrigin && !isManual;

  UserLocationState copyWith({
    GeoLocation? location,
    bool? isLoading,
    bool? isManual,
    String? notice,
    bool clearNotice = false,
  }) {
    return UserLocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      isManual: isManual ?? this.isManual,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class UserLocationNotifier extends Notifier<UserLocationState> {
  @override
  UserLocationState build() => const UserLocationState();

  /// Requests device location; on any failure keeps the current origin and
  /// exposes a human-readable [UserLocationState.notice] so screens can offer
  /// the manual search fallback.
  Future<void> requestDeviceLocation() async {
    state = state.copyWith(isLoading: true, clearNotice: true);

    const service = LocationService();
    final result = await service.getCurrentLocation();

    if (!ref.mounted) return;

    switch (result.status) {
      case LocationStatus.granted when result.location != null:
        state = UserLocationState(
          location: result.location!.copyWith(label: 'Current location'),
          isLoading: false,
        );
      case LocationStatus.denied:
      case LocationStatus.deniedForever:
        state = state.copyWith(
          isLoading: false,
          notice:
              'Location permission is denied. Search for a city or '
              'address instead.',
        );
      case LocationStatus.serviceDisabled:
        state = state.copyWith(
          isLoading: false,
          notice: 'Location services are turned off. Search manually instead.',
        );
      case LocationStatus.unavailable:
      case LocationStatus.granted:
        state = state.copyWith(
          isLoading: false,
          notice: 'Location is unavailable right now. Search manually instead.',
        );
    }
  }

  /// Manual search fallback: a free-text place resolved without a maps API.
  /// For now the label is used to filter stations and distances stay tied to
  /// the last known coordinate origin.
  void setManualLocation(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    state = UserLocationState(
      location: GeoLocation(
        latitude: state.location?.latitude ?? AppConstants.demoOrigin.latitude,
        longitude:
            state.location?.longitude ?? AppConstants.demoOrigin.longitude,
        label: text,
      ),
      isManual: true,
    );
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}

final userLocationProvider =
    NotifierProvider<UserLocationNotifier, UserLocationState>(
      UserLocationNotifier.new,
    );

/// Discovery filter shared by the list, map and home search.
class StationFilterNotifier extends Notifier<StationFilter> {
  @override
  StationFilter build() => StationFilter.empty;

  void update(StationFilter filter) => state = filter;

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleConnector(ConnectorType connector) {
    final next = Set<ConnectorType>.of(state.connectors);
    if (next.contains(connector)) {
      next.remove(connector);
    } else {
      next.add(connector);
    }
    state = state.copyWith(connectors: next);
  }

  void toggleProviderType(StationProviderType type) {
    final next = Set<StationProviderType>.of(state.providerTypes);
    if (next.contains(type)) {
      next.remove(type);
    } else {
      next.add(type);
    }
    state = state.copyWith(providerTypes: next);
  }

  void reset() => state = StationFilter.empty;
}

final stationFilterProvider =
    NotifierProvider<StationFilterNotifier, StationFilter>(
      StationFilterNotifier.new,
    );

/// Filtered station list; re-runs whenever filter or origin change.
final stationsProvider = FutureProvider<List<Station>>((ref) {
  final filter = ref.watch(stationFilterProvider);
  final origin = ref.watch(userLocationProvider.select((s) => s.location));
  final repository = ref.watch(stationRepositoryProvider);
  return repository.getStations(filter: filter, origin: origin);
});

/// Single station detail.
final stationProvider = FutureProvider.family<Station, String>((ref, id) {
  return ref.watch(stationRepositoryProvider).getStation(id);
});

/// Stations owned by the demo/current user (station-owner management).
final myStationsProvider = FutureProvider<List<Station>>((ref) {
  return ref.watch(stationRepositoryProvider).getMyStations();
});
