import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ev_fleet_charging_provider/shared/providers/app_providers.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/cognito_auth_service.dart';
import 'auth_controller.dart';
import '../../data/models/auth_state_model.dart';

final cognitoAuthServiceProvider = Provider<CognitoAuthService>((ref) {
  return CognitoAuthService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    cognitoAuthService: ref.watch(cognitoAuthServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
