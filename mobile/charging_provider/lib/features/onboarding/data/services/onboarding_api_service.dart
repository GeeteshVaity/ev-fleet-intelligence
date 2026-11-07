import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../models/onboarding_model.dart';

class OnboardingApiService {
  OnboardingApiService(DioClient client) : _dio = client.dio;

  final Dio _dio;

  Future<void> updateOnboarding(OnboardingModel onboarding) async {
    await _dio.put('/api/users/me/onboarding', data: onboarding.toJson());
  }
}
