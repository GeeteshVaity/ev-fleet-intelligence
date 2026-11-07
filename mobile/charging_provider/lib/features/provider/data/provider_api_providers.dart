import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import 'provider_api.dart';

final providerApiProvider = Provider<ProviderApi>((ref) {
  return ProviderApi(ref.watch(dioClientProvider).dio);
});

final myProviderStationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(providerApiProvider).getMyStations();
});

final myProviderBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(providerApiProvider);
  final stations = await ref.watch(myProviderStationsProvider.future);

  final bookings = <Map<String, dynamic>>[];

  for (final station in stations) {
    final id = station['id']?.toString();

    if (id == null || id.isEmpty) continue;

    final stationBookings = await api.getStationBookings(id);

    bookings.addAll(
      stationBookings.map(
        (booking) => {
          ...booking,
          '_stationName': station['stationName'] ?? 'Charging station',
          '_stationAddress': station['address'] ?? '',
          '_connectorType': station['connectorType'] ?? '',
          '_powerKw': station['powerKw'] ?? 0,
        },
      ),
    );
  }

  return bookings;
});