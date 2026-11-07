import '../models/provider_profile_model.dart';
import '../services/profile_api_service.dart';

class ProfileRepository {
  ProfileRepository(this._service);

  final ProfileApiService _service;

  Future<ProviderProfileModel?> getMyProfile() {
    return _service.getMyProfile();
  }

  Future<ProviderProfileModel> createProfile(
    ProviderProfileModel profile,
  ) {
    return _service.createProfile(profile);
  }

  Future<ProviderProfileModel> updateProfile(
    ProviderProfileModel profile,
  ) {
    return _service.updateProfile(profile);
  }
}