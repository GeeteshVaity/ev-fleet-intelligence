import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../domain/vehicle.dart';

/// REST data source for vehicles — the Spring Boot integration point.
/// Used only once `API_BASE_URL` is configured.
class VehicleRemoteDataSource {
  VehicleRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Vehicle>> fetchVehicles() async {
    try {
      final response = await _dio.get<dynamic>(ApiConstants.vehiclesPath);
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Vehicle.fromJson)
            .toList();
      }
      if (data is Map<String, dynamic>) {
        final items = data['items'] ?? data['content'] ?? data['data'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map(Vehicle.fromJson)
              .toList();
        }
      }
      throw const ParseException('Unexpected vehicle list payload');
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.vehiclesPath,
        data: vehicle.toJson(),
      );
      return Vehicle.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    try {
      final response = await _dio.put<dynamic>(
        '${ApiConstants.vehiclesPath}/${vehicle.id}',
        data: vehicle.toJson(),
      );
      return Vehicle.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _dio.delete<dynamic>('${ApiConstants.vehiclesPath}/$id');
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ParseException('Unexpected vehicle payload');
  }
}
