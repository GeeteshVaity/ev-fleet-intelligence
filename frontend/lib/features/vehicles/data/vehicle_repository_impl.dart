import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../domain/vehicle.dart';
import '../domain/vehicle_repository.dart';
import 'mock_vehicle_repository.dart';
import 'vehicle_remote_data_source.dart';

/// Vehicle repository backed by the Spring Boot REST API.
class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl(this._remote);

  final VehicleRemoteDataSource _remote;

  @override
  Future<List<Vehicle>> getVehicles() => _remote.fetchVehicles();

  @override
  Future<Vehicle> getVehicle(String id) async {
    final vehicles = await _remote.fetchVehicles();
    return vehicles.firstWhere(
      (v) => v.id == id,
      orElse: () => throw StateError('Vehicle not found'),
    );
  }

  @override
  Future<Vehicle> addVehicle(Vehicle vehicle) => _remote.createVehicle(vehicle);

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) =>
      _remote.updateVehicle(vehicle);

  @override
  Future<void> deleteVehicle(String id) => _remote.deleteVehicle(id);
}

/// DI: demo repository until `API_BASE_URL` is configured.
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  if (ApiConstants.isMockBackend) return MockVehicleRepository();
  return VehicleRepositoryImpl(
    VehicleRemoteDataSource(ref.watch(dioClientProvider)),
  );
});
