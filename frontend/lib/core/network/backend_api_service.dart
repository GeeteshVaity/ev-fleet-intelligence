import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'dio_client.dart';

/// Transport layer for the Spring Boot backend.
///
/// Every method returns decoded JSON (or a status code) and converts transport
/// failures into [AppException]s whose messages are already safe to show to a
/// user. Mapping JSON onto UI models happens in the feature layer so that the
/// UI models stay the single source of truth for the presentation.
///
/// Nothing here falls back to sample data: a failed request throws.
class BackendApiService {
  BackendApiService(this._dio);

  final Dio _dio;

  // --------------------------------------------------------------------------
  // Authentication / profile
  // --------------------------------------------------------------------------

  /// GET /api/auth/me — claims from the validated Cognito access token plus
  /// the local profile when it exists (`profileCreated: false` otherwise).
  Future<Map<String, dynamic>> fetchAuthMe() async {
    final body = await _get('/api/auth/me');
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response from the server.');
    }
    return body;
  }

  /// PUT /api/users/me — creates or updates the local profile.
  Future<void> saveProfile({
    required String fullName,
    required String email,
    String? phone,
    String? role,
  }) async {
    await _request(
      'PUT',
      ApiConstants.profilePath,
      data: {
        'fullName': fullName,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );
  }

  /// PUT /api/users/me/onboarding — persists role selection and progress.
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

  /// GET /api/users/me — the local profile, or null when it has not been
  /// created yet (the backend answers 404 in that case).
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    try {
      final body = await _get(ApiConstants.profilePath);
      if (body is! Map<String, dynamic>) {
        throw const ParseException('Unexpected response from the server.');
      }
      return body;
    } on ServerException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Stations (public discovery)
  // --------------------------------------------------------------------------

  /// GET /api/stations — active stations, newest data straight from RDS.
  Future<List<dynamic>> fetchStations() async {
    final body = await _get(ApiConstants.stationsPath);
    if (body is! List) {
      throw const ParseException('Unexpected station list response.');
    }
    return body;
  }

  /// GET /api/stations/{id}/availability — published charging windows.
  Future<List<dynamic>> fetchAvailability(int stationId) async {
    final body = await _get(
      '${ApiConstants.stationsPath}/$stationId/availability',
    );
    if (body is! List) {
      throw const ParseException('Unexpected availability response.');
    }
    return body;
  }

  /// GET /api/stations/nearby — server-side radius search.
  ///
  /// The backend validates the coordinates, excludes inactive stations and
  /// returns only stations within [radiusKm], sorted by distance. The client
  /// does not download the whole catalogue and filter it locally.
  Future<List<dynamic>> fetchNearbyStations({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    // Fail fast on nonsense input instead of sending it to the server.
    if (latitude < -90 || latitude > 90) {
      throw const ParseException('Latitude must be between -90 and 90.');
    }
    if (longitude < -180 || longitude > 180) {
      throw const ParseException('Longitude must be between -180 and 180.');
    }
    if (radiusKm <= 0 || radiusKm > maxSearchRadiusKm) {
      throw ParseException(
        'Radius must be between 0 and $maxSearchRadiusKm km.',
      );
    }
    final body = await _get(
      '${ApiConstants.stationsPath}/nearby',
      query: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
      },
    );
    if (body is! List) {
      throw const ParseException('Unexpected station list response.');
    }
    return body;
  }

  /// Largest radius the client will request. The backend rejects non-positive
  /// radii; the cap keeps a typo from turning a nearby search into a global
  /// scan.
  static const double maxSearchRadiusKm = 50;

  /// GET /api/stations/mine — stations owned by the signed-in provider.
  Future<List<dynamic>> fetchMyStations() async {
    final body = await _get('${ApiConstants.stationsPath}/mine');
    if (body is! List) {
      throw const ParseException('Unexpected station list response.');
    }
    return body;
  }

  /// POST /api/stations — creates a listing owned by the signed-in provider.
  Future<Map<String, dynamic>> createStation({
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
    final body = await _request(
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
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response creating the station.');
    }
    return body;
  }

  // --------------------------------------------------------------------------
  // Vehicles (scoped to the signed-in user by the backend)
  // --------------------------------------------------------------------------

  Future<List<dynamic>> fetchVehicles() async {
    final body = await _get(ApiConstants.vehiclesPath);
    if (body is! List) {
      throw const ParseException('Unexpected vehicle list response.');
    }
    return body;
  }

  Future<Map<String, dynamic>> createVehicle({
    required String vehicleType,
    required String model,
    String? brand,
    String? registrationNumber,
    double? batteryCapacityKwh,
    String? connectorType,
  }) async {
    final body = await _request(
      'POST',
      ApiConstants.vehiclesPath,
      data: {
        'vehicleType': vehicleType,
        'model': model,
        if (brand != null && brand.isNotEmpty) 'brand': brand,
        if (registrationNumber != null && registrationNumber.isNotEmpty)
          'registrationNumber': registrationNumber,
        if (batteryCapacityKwh != null)
          'batteryCapacityKwh': batteryCapacityKwh,
        if (connectorType != null && connectorType.isNotEmpty)
          'connectorType': connectorType,
      },
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response creating the vehicle.');
    }
    return body;
  }

  Future<void> deleteVehicle(int id) async {
    await _request('DELETE', '${ApiConstants.vehiclesPath}/$id', data: null);
  }

  // --------------------------------------------------------------------------
  // Availability windows (station owner only, enforced by the backend)
  // --------------------------------------------------------------------------

  /// POST /api/stations/{id}/availability — publishes a charging window.
  Future<Map<String, dynamic>> addAvailability(
    int stationId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final body = await _request(
      'POST',
      '${ApiConstants.stationsPath}/$stationId/availability',
      data: {
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
        'status': 'AVAILABLE',
      },
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response saving availability.');
    }
    return body;
  }

  /// DELETE /api/stations/{id}/availability/{windowId}
  Future<void> deleteAvailability(int stationId, int windowId) async {
    await _request(
      'DELETE',
      '${ApiConstants.stationsPath}/$stationId/availability/$windowId',
      data: null,
    );
  }

  /// GET /api/stations/{id}/bookings — booking requests for an owned station.
  Future<List<dynamic>> fetchStationBookings(int stationId) async {
    final body = await _get('${ApiConstants.stationsPath}/$stationId/bookings');
    if (body is! List) {
      throw const ParseException('Unexpected booking list response.');
    }
    return body;
  }

  // --------------------------------------------------------------------------
  // Bookings
  // --------------------------------------------------------------------------

  Future<List<dynamic>> fetchBookings() async {
    final body = await _get(ApiConstants.bookingsPath);
    if (body is! List) {
      throw const ParseException('Unexpected booking list response.');
    }
    return body;
  }

  /// POST /api/bookings — the backend re-validates ownership, connector
  /// compatibility, availability and overlap before persisting.
  Future<Map<String, dynamic>> createBooking({
    required int vehicleId,
    required int stationId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final body = await _request(
      'POST',
      ApiConstants.bookingsPath,
      data: {
        'vehicleId': vehicleId,
        'stationId': stationId,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
      },
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response creating the booking.');
    }
    return body;
  }

  /// PUT /api/bookings/{id}/confirm — provider accepts a PENDING request.
  /// The backend only allows the station owner to do this and only while the
  /// booking is still PENDING; anything else surfaces as an AppException.
  Future<Map<String, dynamic>> confirmBooking(int id) async {
    final body = await _request(
      'PUT',
      '${ApiConstants.bookingsPath}/$id/confirm',
      data: null,
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response confirming the booking.');
    }
    return body;
  }

  /// PUT /api/bookings/{id}/reject — provider declines a PENDING request.
  Future<Map<String, dynamic>> rejectBooking(int id) async {
    final body = await _request(
      'PUT',
      '${ApiConstants.bookingsPath}/$id/reject',
      data: null,
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response rejecting the booking.');
    }
    return body;
  }

  /// PUT /api/stations/{id}/status — publish or hide a listing.
  Future<Map<String, dynamic>> setStationActive(int id, {required bool active}) async {
    final body = await _request(
      'PUT',
      '${ApiConstants.stationsPath}/$id/status',
      data: {'active': active},
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response updating the station.');
    }
    return body;
  }

  /// PUT /api/bookings/{id}/cancel
  Future<Map<String, dynamic>> cancelBooking(int id) async {
    final body = await _request(
      'PUT',
      '${ApiConstants.bookingsPath}/$id/cancel',
      data: null,
    );
    if (body is! Map<String, dynamic>) {
      throw const ParseException('Unexpected response cancelling the booking.');
    }
    return body;
  }

  // --------------------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------------------

  void _requireBackend() {
    if (!ApiConstants.isBackendConfigured) {
      throw NotConfiguredException(
        ApiConstants.isMockBackend
            ? 'The app is running in demo mode, so no server request is made.'
            : 'The backend URL is not configured for this build.',
        code: 'backend_not_configured',
      );
    }
  }

  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    _requireBackend();
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
      );
      return response.data;
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }

  Future<Object?> _request(String method, String path, {Object? data}) async {
    _requireBackend();
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (error) {
      throw normalizeException(error);
    }
  }
}

final backendApiServiceProvider = Provider<BackendApiService>(
  (ref) => BackendApiService(ref.watch(dioClientProvider)),
);
