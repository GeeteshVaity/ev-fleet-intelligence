import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../domain/booking.dart';

/// REST data source for bookings — the Spring Boot integration point.
///
/// The backend owns availability checks, conflict prevention and
/// cancellation authorization; this class only transports requests.
class BookingRemoteDataSource {
  BookingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Booking>> fetchBookings() async {
    try {
      final response = await _dio.get<dynamic>(ApiConstants.bookingsPath);
      return _asList(response.data);
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Booking> fetchBooking(String id) async {
    try {
      final response = await _dio.get<dynamic>(
        '${ApiConstants.bookingsPath}/$id',
      );
      return Booking.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Booking> createBooking(CreateBookingInput input) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.bookingsPath,
        data: {
          'stationId': input.stationId,
          'vehicleId': input.vehicleId,
          'startTime': input.startTime.toIso8601String(),
          'endTime': input.endTime.toIso8601String(),
          if (input.estimatedEnergyKwh != null)
            'estimatedEnergyKwh': input.estimatedEnergyKwh,
          if (input.estimatedCost != null) 'estimatedCost': input.estimatedCost,
        },
      );
      return Booking.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Booking> cancelBooking(String id) async {
    try {
      final response = await _dio.patch<dynamic>(
        '${ApiConstants.bookingsPath}/$id/cancel',
      );
      return Booking.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<List<Booking>> fetchBookingsForStation(String stationId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.bookingsPath,
        queryParameters: {'stationId': stationId},
      );
      return _asList(response.data);
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ParseException('Unexpected booking payload');
  }

  List<Booking> _asList(Object? data) {
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['content'] ?? data['data'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();
      }
    }
    throw const ParseException('Unexpected booking list payload');
  }
}
