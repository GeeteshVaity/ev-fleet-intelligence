import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import 'dio_client.dart';

class BackendApiService {
  BackendApiService(this._dio);

  final Dio _dio;

  Future<void> saveProfile({
    required String fullName,
    required String email,
    required String role,
  }) async {
    await _request(
      'PUT',
      ApiConstants.profilePath,
      data: {
        'fullName': fullName,
        'email': email,
        'role': role,
      },
    );
  }

  Future<void> saveOnboarding({
    required String role,
    required bool completed,
    required int step,
  }) async {
    await _request(
      'PUT',
      '${ApiConstants.profilePath}/onboarding',
      data: {
        'role': role,
        'onboardingCompleted': completed,
        'onboardingStep': step,
      },
    );
  }

  Future<void> createVehicle({
    required String vehicleType,
    required String model,
    String? brand,
    String? registrationNumber,
    double? batteryCapacityKwh,
    String? connectorType,
  }) async {
    await _request(
      'POST',
      ApiConstants.vehiclesPath,
      data: {
        'vehicleType': vehicleType,
        'model': model,
        if (brand?.isNotEmpty == true) 'brand': brand,
        if (registrationNumber?.isNotEmpty == true)
          'registrationNumber': registrationNumber,
        if (batteryCapacityKwh != null)
          'batteryCapacityKwh': batteryCapacityKwh,
        if (connectorType?.isNotEmpty == true) 'connectorType': connectorType,
      },
    );
  }

  Future<void> createStation({
    required String stationName,
    required String providerType,
    required String accessType,
    required String address,
    required double latitude,
    required double longitude,
    required String connectorType,
    required double powerKw,
    double? pricePerKwh,
  }) async {
    await _request(
      'POST',
      ApiConstants.stationsPath,
      data: {
        'stationName': stationName,
        'providerType': providerType,
        'accessType': accessType,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'connectorType': connectorType,
        'powerKw': powerKw,
        if (pricePerKwh != null) 'pricePerKwh': pricePerKwh,
      },
    );
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    await _request(
      'PUT',
      ApiConstants.profilePath,
      data: {
        'fullName': fullName,
        'email': email,
        if (phone?.isNotEmpty == true) 'phone': phone,
      },
    );
  }

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    required Map<String, dynamic> data,
  }) async {
    if (!ApiConstants.isBackendConfigured) {
      throw StateError(
        'Backend is not configured. Start the app with '
        '--dart-define=API_BASE_URL=http://localhost:8080.',
      );
    }

    return _dio.request<dynamic>(
      path,
      data: data,
      options: Options(method: method),
    );
  }
}

final backendApiServiceProvider = Provider<BackendApiService>(
  (ref) => BackendApiService(ref.watch(dioClientProvider)),
);
