import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Cognito User Pool values. They come from `--dart-define` (or the build
/// script) and are **never guessed, committed or embedded** — the pool itself
/// already exists in AWS.
class CognitoConfig {
  const CognitoConfig({
    required this.userPoolId,
    required this.region,
    required this.appClientId,
    this.redirectUri,
  });

  final String userPoolId;
  final String region;
  final String appClientId;
  final String? redirectUri;

  bool get isComplete =>
      userPoolId.isNotEmpty && region.isNotEmpty && appClientId.isNotEmpty;

  /// Reads the configuration injected at build time.
  factory CognitoConfig.fromEnvironment() => CognitoConfig(
    userPoolId: ApiConstants.cognitoUserPoolId,
    region: ApiConstants.cognitoRegion,
    appClientId: ApiConstants.cognitoAppClientId,
    redirectUri: ApiConstants.cognitoRedirectUri.isEmpty
        ? null
        : ApiConstants.cognitoRedirectUri,
  );

  String describe() =>
      'userPoolId=${userPoolId.isEmpty ? '<missing>' : userPoolId}, '
      'region=${region.isEmpty ? '<missing>' : region}, '
      'appClientId=${appClientId.isEmpty ? '<missing>' : appClientId}';
}

/// The authentication seam that Amazon Cognito plugs into.
///
/// Operations cover the full required surface (sign-up, email confirmation,
/// sign-in, forgot/reset password, sign-out, token refresh, secure storage,
/// authenticated calls through the Dio interceptor). Each one fails with an
/// explicit [NotConfiguredException]/[AuthException] until the real
/// transport is installed — it **never fabricates a successful sign-in**.
///
/// The intended transport is a maintained OIDC authorization-code + PKCE
/// flow (e.g. `flutter_appauth`) against the existing User Pool. The exact
/// switch-over steps are documented in README → "Connecting Cognito".
class CognitoAuthService {
  CognitoAuthService({CognitoConfig? config, SecureStorageService? storage})
    : config = config ?? CognitoConfig.fromEnvironment(),
      _storage = storage ?? SecureStorageService();

  final CognitoConfig config;
  final SecureStorageService _storage;

  bool get isConfigured => config.isComplete;

  /// Guard every operation: without pool values there is nothing to call.
  Never _fail(String operation) {
    if (!config.isConfigured) {
      throw NotConfiguredException(
        'Cognito sign-in is not configured yet ($operation). '
        'Set COGNITO_USER_POOL_ID, AWS_REGION and COGNITO_APP_CLIENT_ID — '
        'see README → "Connecting Cognito to the app".',
        code: 'cognito_not_configured',
      );
    }
    throw AuthException(
      'The Cognito transport for "$operation" is not installed yet. '
      'Follow README → "Connecting Cognito to the app" to add the OIDC '
      'authorization-code + PKCE flow.',
      code: 'cognito_transport_missing',
    );
  }

  /// Restores a stored session (tokens live in secure storage only).
  Future<AuthUser?> restoreSession() async {
    final token = await _storage.readAccessToken();
    if (token == null) return null;
    _fail('session restore');
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _fail('sign-in');

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async => _fail('sign-up');

  Future<AuthUser> confirmEmail({
    required String email,
    required String code,
  }) async => _fail('email confirmation');

  Future<void> resendVerificationCode({required String email}) async =>
      _fail('resend code');

  Future<void> requestPasswordReset({required String email}) async =>
      _fail('forgot password');

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async => _fail('password reset');

  Future<void> signOut() async {
    // Signing out only ever *removes* local credentials; safe to run even
    // when Cognito is not configured.
    await _storage.clearSession();
    if (!config.isConfigured) return;
    _fail('sign-out');
  }

  /// Exchanges the stored refresh token for a new access token.
  Future<void> refreshSession() async => _fail('token refresh');
}

/// DI for the Cognito service (used by [AuthRepositoryImpl]).
final cognitoAuthServiceProvider = Provider<CognitoAuthService>((ref) {
  return CognitoAuthService(storage: ref.watch(secureStorageProvider));
});
