import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../data/models/provider_profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/profile_api_service.dart';

final profileApiServiceProvider = Provider<ProfileApiService>((ref) {
  return ProfileApiService(ref.watch(dioClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(profileApiServiceProvider));
});

final providerProfileProvider =
    AsyncNotifierProvider<ProviderProfileController, ProviderProfileModel?>(
  ProviderProfileController.new,
);

class ProviderProfileController
    extends AsyncNotifier<ProviderProfileModel?> {
  late final ProfileRepository _repository;

  @override
  Future<ProviderProfileModel?> build() async {
    _repository = ref.watch(profileRepositoryProvider);
    return _repository.getMyProfile();
  }

  Future<ProviderProfileModel> saveProfile(
    ProviderProfileModel profile, {
    required bool isNew,
  }) async {
    state = const AsyncLoading();

    try {
      final result = isNew
          ? await _repository.createProfile(profile)
          : await _repository.updateProfile(profile);

      state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();

    try {
      state = AsyncData(await _repository.getMyProfile());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}