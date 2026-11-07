import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../models/provider_profile_model.dart';

class ProfileApiService {
  ProfileApiService(DioClient client) : _dio = client.dio;

  final Dio _dio;

  Future<ProviderProfileModel?> getMyProfile() async {
    try {
      final response = await _dio.get('/api/users/me');

      return ProviderProfileModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<ProviderProfileModel> createProfile(
    ProviderProfileModel profile,
  ) async {
    final response = await _dio.post(
      '/api/users/me',
      data: profile.toJson(),
    );

    return ProviderProfileModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ProviderProfileModel> updateProfile(
    ProviderProfileModel profile,
  ) async {
    final response = await _dio.put(
      '/api/users/me',
      data: profile.toJson(),
    );

    return ProviderProfileModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}