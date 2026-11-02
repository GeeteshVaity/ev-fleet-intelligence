import 'vehicle.dart';

/// Contract for vehicle data access.
abstract interface class VehicleRepository {
  Future<List<Vehicle>> getVehicles();

  Future<Vehicle> getVehicle(String id);

  /// Creates a vehicle. Throws [ValidationException] for invalid input.
  Future<Vehicle> addVehicle(Vehicle vehicle);

  Future<Vehicle> updateVehicle(Vehicle vehicle);

  /// Deletes a vehicle. Only succeeds when the backend/mock accepts the
  /// deletion — errors are surfaced, never swallowed.
  Future<void> deleteVehicle(String id);
}
