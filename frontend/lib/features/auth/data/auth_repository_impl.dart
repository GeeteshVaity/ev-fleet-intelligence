import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'cognito_auth_service.dart';
import 'mock_auth_repository.dart';

/// Production authentication repository: delegates to [CognitoAuthService]
/// and keeps tokens in secure storage (never in SharedPreferences).
///
/// It is selected by `authRepositoryProvider` only once the Cognito values
/// are configured — see below.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._cognito, this._storage);

  final CognitoAuthService _cognito;
  final SecureStorageService _storage;

  @override
  bool get isMock => false;

  @override
  Future<AuthUser?> restoreSession() => _cognito.restoreSession();

  @override
  Future<AuthUser> signIn({required String email, required String password}) {
    // The Cognito flow stores the returned tokens in secure storage and the
    // Dio interceptor attaches them to every API request.
    return _cognito.signIn(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => _cognito.signUp(fullName: fullName, email: email, password: password);

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) => _cognito.confirmEmail(email: email, code: code);

  @override
  Future<void> resendVerificationCode({required String email}) =>
      _cognito.resendVerificationCode(email: email);

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _cognito.requestPasswordReset(email: email);

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) => _cognito.confirmPasswordReset(
    email: email,
    code: code,
    newPassword: newPassword,
  );

  @override
  Future<void> signOut() async {
    await _cognito.signOut();
    await _storage.clearSession();
  }

  @override
  Future<AuthUser> updateProfile(AuthUser user) async {
    // Profile updates go to the Spring Boot API once configured; Cognito is
    // only the identity provider.
    throw UnsupportedError(
      'Profile updates require the Spring Boot API (API_BASE_URL). '
      'Current configuration: ${ApiConstants.apiBaseUrl.isEmpty ? "unset" : "set"}.',
    );
  }
}

/// DI: Cognito implementation when the pool is configured, development-only
/// mock authentication otherwise. The two are never mixed.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ApiConstants.isCognitoConfigured) {
    return AuthRepositoryImpl(
      ref.watch(cognitoAuthServiceProvider),
      ref.watch(secureStorageProvider),
    );
  }
  return MockAuthRepository();
});
