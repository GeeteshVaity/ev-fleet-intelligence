import 'package:dio/dio.dart';

class ProviderApi {
  ProviderApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> getMyStations() async {
    final response = await _dio.get('/api/stations/mine');

    if (response.data is! List) {
      throw const FormatException('Invalid stations response.');
    }

    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createStation(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/api/stations', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateStation(
    String stationId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.put(
      '/api/stations/$stationId',
      data: body,
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateStationStatus(String id, bool active) async {
    await _dio.put(
      '/api/stations/$id/status',
      data: {'active': active},
    );
  }

  Future<void> deactivateStation(String id) async {
    await _dio.delete('/api/stations/$id');
  }

  Future<List<Map<String, dynamic>>> getAvailability(
    String stationId,
  ) async {
    final response = await _dio.get(
      '/api/stations/$stationId/availability',
    );

    if (response.data is! List) {
      throw const FormatException('Invalid availability response.');
    }

    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createAvailability(
    String stationId, {
    required String startTime,
    required String endTime,
  }) async {
    final response = await _dio.post(
      '/api/stations/$stationId/availability',
      data: {
        'startTime': startTime,
        'endTime': endTime,
        'status': 'AVAILABLE',
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateAvailability(
    String stationId,
    String windowId, {
    required String startTime,
    required String endTime,
  }) async {
    final response = await _dio.put(
      '/api/stations/$stationId/availability/$windowId',
      data: {
        'startTime': startTime,
        'endTime': endTime,
        'status': 'AVAILABLE',
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteAvailability(
    String stationId,
    String windowId,
  ) async {
    await _dio.delete(
      '/api/stations/$stationId/availability/$windowId',
    );
  }

  Future<List<Map<String, dynamic>>> getStationBookings(
    String stationId,
  ) async {
    final response = await _dio.get(
      '/api/stations/$stationId/bookings',
    );

    if (response.data is! List) {
      throw const FormatException('Invalid bookings response.');
    }

    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> confirmBooking(String id) async {
    await _dio.put('/api/bookings/$id/confirm');
  }

  Future<void> rejectBooking(String id) async {
    await _dio.put('/api/bookings/$id/reject');
  }

  Future<Map<String, dynamic>> startSession(String bookingId) async {
    final response = await _dio.post(
      '/api/bookings/$bookingId/sessions',
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> completeSession({
    required String sessionId,
    required double energyConsumedKwh,
  }) async {
    final response = await _dio.put(
      '/api/sessions/$sessionId/complete',
      data: {
        'energyConsumedKwh': energyConsumedKwh,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }


  Future<Map<String, dynamic>?> getBookingSession(
    String bookingId,
  ) async {
    try {
      final response = await _dio.get(
        '/api/bookings/$bookingId/session',
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }


}
