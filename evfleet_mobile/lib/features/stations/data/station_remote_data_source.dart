import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../domain/station.dart';

/// REST data source for stations — the Spring Boot integration point.
///
/// Paths follow the expected `/api/v1/stations` contract; DTOs are parsed
/// through [Station.fromJson]. It is only used once `API_BASE_URL` is
/// configured (see [ApiConstants.isMockBackend]) — in demo mode the mock
/// repository serves data instead and this class is never called.
class StationRemoteDataSource {
  StationRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Station>> fetchStations({Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.stationsPath,
        queryParameters: query,
      );
      return _asStationList(response.data);
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Station> fetchStation(String id) async {
    try {
      final response = await _dio.get<dynamic>(
        '${ApiConstants.stationsPath}/$id',
      );
      return Station.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Station> createStation(CreateStationInput input) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.stationsPath,
        data: input.toJson(),
      );
      return Station.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Station> updateStation(String id, CreateStationInput input) async {
    try {
      final response = await _dio.put<dynamic>(
        '${ApiConstants.stationsPath}/$id',
        data: input.toJson(),
      );
      return Station.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Future<Station> setActive(String id, bool active) async {
    try {
      final response = await _dio.put<dynamic>(
        '${ApiConstants.stationsPath}/$id/status',
        data: {'active': active},
      );
      return Station.fromJson(_asMap(response.data));
    } catch (error, stackTrace) {
      throw normalizeException(error, stackTrace);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw ParseException('Unexpected station payload from the server');
  }

  List<Station> _asStationList(Object? data) {
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Station.fromJson)
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['content'] ?? data['data'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(Station.fromJson)
            .toList();
      }
    }
    throw ParseException('Unexpected station list payload from the server');
  }
}
