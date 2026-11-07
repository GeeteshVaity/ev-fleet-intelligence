import 'package:dio/dio.dart';

import '../models/station_model.dart';

class StationRepository {
  StationRepository(this._dio);

  final Dio _dio;

  Future<List<Station>> getPublicStations() async {
    try {
      final response = await _dio.get('/api/stations');

      final data = response.data;

      if (data is! List) {
        throw const FormatException(
          'Expected a list of stations from the API.',
        );
      }

      return data
          .map(
            (item) => Station.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data ?? e.message ?? 'Failed to fetch stations',
      );
    }
  }
}