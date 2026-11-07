import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import 'provider_api.dart';

final providerApiProvider = Provider<ProviderApi>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ProviderApi(dioClient.dio);
});

final providerStationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerApiProvider).getMyStations();
});

final providerBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(providerApiProvider);
  final stations = await ref.watch(providerStationsProvider.future);

  final allBookings = <Map<String, dynamic>>[];

  for (final station in stations) {
    final stationId = station['id']?.toString();

    if (stationId == null || stationId.isEmpty) continue;

    final bookings = await api.getStationBookings(stationId);

    allBookings.addAll(
      bookings.map(
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

  allBookings.sort((a, b) {
    final dateA = DateTime.tryParse(
          a['createdAt']?.toString() ?? '',
        ) ??
        DateTime(2000);

    final dateB = DateTime.tryParse(
          b['createdAt']?.toString() ?? '',
        ) ??
        DateTime(2000);

    return dateB.compareTo(dateA);
  });

  return allBookings;
});