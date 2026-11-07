import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../data/models/onboarding_model.dart';
import '../../data/repositories/onboarding_repository.dart';
import '../../data/services/onboarding_api_service.dart';

final onboardingApiServiceProvider =
    Provider<OnboardingApiService>((ref) {
  return OnboardingApiService(ref.watch(dioClientProvider));
});

final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(onboardingApiServiceProvider));
});

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(
  OnboardingController.new,
);

class OnboardingController extends AsyncNotifier<void> {
  late final OnboardingRepository _repository;

  @override
  Future<void> build() async {
    _repository = ref.watch(onboardingRepositoryProvider);
  }

  Future<void> saveProgress({
    required int step,
    bool completed = false,
  }) async {
    state = const AsyncLoading();

    try {
      await _repository.updateOnboarding(
        OnboardingModel(
          role: 'CHARGER_PROVIDER',
          onboardingCompleted: completed,
          onboardingStep: step,
        ),
      );

      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}