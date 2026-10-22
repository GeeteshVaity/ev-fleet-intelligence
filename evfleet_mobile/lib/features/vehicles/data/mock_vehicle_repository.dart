import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../stations/domain/station.dart';
import '../domain/vehicle.dart';
import '../domain/vehicle_repository.dart';

/// ---------------------------------------------------------------------------
/// DEMO DATA — sample vehicles for UI development. Not backed by a server.
/// ---------------------------------------------------------------------------
abstract final class DemoVehicles {
  static List<Vehicle> all() => [
    const Vehicle(
      id: 'veh-1',
      brand: 'Tesla',
      model: 'Model 3 Long Range',
      type: VehicleType.car,
      registrationNumber: 'B-EV 1012',
      batteryCapacityKwh: 75,
      connectorType: ConnectorType.ccs2,
      nickname: 'Daily driver',
    ),
    const Vehicle(
      id: 'veh-2',
      brand: 'Volkswagen',
      model: 'ID.4 Pro',
      type: VehicleType.suv,
      batteryCapacityKwh: 77,
      connectorType: ConnectorType.ccs2,
    ),
  ];
}

/// Development-only in-memory [VehicleRepository].
class MockVehicleRepository implements VehicleRepository {
  MockVehicleRepository({List<Vehicle>? seed})
    : _vehicles = seed ?? DemoVehicles.all();

  final List<Vehicle> _vehicles;

  Future<void> _delay() => Future<void>.delayed(AppConstants.mockLatency);

  @override
  Future<List<Vehicle>> getVehicles() async {
    await _delay();
    return List<Vehicle>.of(_vehicles);
  }

  @override
  Future<Vehicle> getVehicle(String id) async {
    await _delay();
    return _vehicles.firstWhere(
      (v) => v.id == id,
      orElse: () => throw const ValidationException('Vehicle not found'),
    );
  }

  @override
  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    await _delay();
    final created = Vehicle(
      id: 'veh-${DateTime.now().millisecondsSinceEpoch}',
      brand: vehicle.brand,
      model: vehicle.model,
      type: vehicle.type,
      registrationNumber: vehicle.registrationNumber,
      batteryCapacityKwh: vehicle.batteryCapacityKwh,
      connectorType: vehicle.connectorType,
      nickname: vehicle.nickname,
    );
    _vehicles.add(created);
    return created;
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    await _delay();
    final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index == -1) throw const ValidationException('Vehicle not found');
    _vehicles[index] = vehicle;
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await _delay();
    final index = _vehicles.indexWhere((v) => v.id == id);
    if (index == -1) {
      throw const ValidationException('Vehicle not found');
    }
    _vehicles.removeAt(index);
  }
}
