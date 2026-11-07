import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../models/station_model.dart';
import '../repositories/station_repository.dart';

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  final dio = ref.watch(dioClientProvider).dio;

  return StationRepository(dio);
});

final publicStationsProvider = FutureProvider<List<Station>>((ref) {
  final repository = ref.watch(stationRepositoryProvider);

  return repository.getPublicStations();
});