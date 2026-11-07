import '../models/onboarding_model.dart';
import '../services/onboarding_api_service.dart';

class OnboardingRepository {
  OnboardingRepository(this._service);

  final OnboardingApiService _service;

  Future<void> updateOnboarding(OnboardingModel onboarding) {
    return _service.updateOnboarding(onboarding);
  }
}