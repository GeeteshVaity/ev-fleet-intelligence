import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart' as errors;
import '../../../core/storage/secure_storage_service.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart' as domain;

class CognitoConfig {
  const CognitoConfig({
    required this.userPoolId,
    required this.region,
    required this.appClientId,
  });

  final String userPoolId;
  final String region;
  final String appClientId;

  bool get isComplete =>
      userPoolId.isNotEmpty && region.isNotEmpty && appClientId.isNotEmpty;
}

/// Thin adapter around Amplify Auth. Pool values are injected at build time.
class CognitoAuthService {
  CognitoAuthService({CognitoConfig? config, SecureStorageService? storage})
    : config = config ??
          CognitoConfig(
            userPoolId: ApiConstants.cognitoUserPoolId,
            region: ApiConstants.cognitoRegion,
            appClientId: ApiConstants.cognitoAppClientId,
          ),
      _storage = storage ?? SecureStorageService();

  final CognitoConfig config;
  final SecureStorageService _storage;
  static bool _configured = false;
  static String? _configuredKey;

  bool get isConfigured => config.isComplete;

  Future<void> _ensureConfigured() async {
    if (!isConfigured) {
      throw const errors.NotConfiguredException(
        'Cognito is not configured. Provide COGNITO_USER_POOL_ID, AWS_REGION '
        'and COGNITO_APP_CLIENT_ID.',
        code: 'cognito_not_configured',
      );
    }

    final key = '${config.userPoolId}|${config.region}|${config.appClientId}';
    if (_configured && _configuredKey == key) return;
    if (_configured && _configuredKey != key) {
      throw const errors.AuthException(
        'Amplify was already configured with different Cognito settings.',
        code: 'cognito_configuration_conflict',
      );
    }

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
    } on AmplifyException catch (error) {
      if (!error.message.toLowerCase().contains('already')) {
        throw errors.AuthException(
          error.message,
          code: error.recoverySuggestion,
          cause: error,
        );
      }
    }
    try {
      await Amplify.configure(jsonEncode({
        'auth': {
          'plugins': {
            'awsCognitoAuthPlugin': {
              'CognitoUserPool': {
                'Default': {
                  'PoolId': config.userPoolId,
                  'AppClientId': config.appClientId,
                  'Region': config.region,
                },
              },
              'Auth': {
                'Default': {
                  'authenticationFlowType': 'USER_SRP_AUTH',
                  'usernameAttributes': ['email'],
                },
              },
            },
          },
        },
      }));
      _configured = true;
      _configuredKey = key;
    } on AmplifyException catch (error) {
      throw errors.AuthException(
        error.message,
        code: error.recoverySuggestion,
        cause: error,
      );
    }
  }

  Future<domain.AuthUser?> restoreSession() async {
    await _ensureConfigured();
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        await _storage.clearSession();
        return null;
      }
      await _saveTokens(session);
      return _currentUser();
    } on errors.AuthException {
      rethrow;
    } on AmplifyException catch (error) {
      await _storage.clearSession();
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<domain.AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await _ensureConfigured();
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );
      if (!result.isSignedIn) {
        throw errors.AuthException(
          'Additional sign-in verification is required.',
          code: result.nextStep.signInStep.name,
        );
      }
      final session = await Amplify.Auth.fetchAuthSession();
      await _saveTokens(session);
      return _currentUser();
    } on errors.AuthException {
      rethrow;
    } on AmplifyException catch (error) {
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _ensureConfigured();
    try {
      await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
            AuthUserAttributeKey.name: fullName,
          },
        ),
      );
    } on AmplifyException catch (error) {
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    await _ensureConfigured();
    try {
      await Amplify.Auth.confirmSignUp(username: email, confirmationCode: code);
    } on AmplifyException catch (error) {
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<void> resendVerificationCode({required String email}) async {
    await _ensureConfigured();
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
    } on AmplifyException catch (error) {
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _ensureConfigured();
    try {
      await Amplify.Auth.resetPassword(username: email);
    } on AmplifyException catch (error) {
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _ensureConfigured();
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: code,
      );
    } on AmplifyException catch (error) {
      throw errors.AuthException(error.message, code: error.recoverySuggestion);
    }
  }

  Future<void> signOut() async {
    if (isConfigured) {
      await _ensureConfigured();
      try {
        await Amplify.Auth.signOut();
      } on AmplifyException catch (error) {
        throw errors.AuthException(error.message, code: error.recoverySuggestion);
      }
    }
    await _storage.clearSession();
  }

  Future<void> refreshSession() async {
    await _ensureConfigured();
    final session = await Amplify.Auth.fetchAuthSession();
    await _saveTokens(session);
  }

  Future<domain.AuthUser> _currentUser() async {
    final user = await Amplify.Auth.getCurrentUser();
    final attributes = await Amplify.Auth.fetchUserAttributes();
    final values = <String, String>{
      for (final attribute in attributes) attribute.userAttributeKey.key: attribute.value,
    };
    return domain.AuthUser(
      id: user.userId,
      email: values[AuthUserAttributeKey.email.key] ?? user.username,
      fullName: values[AuthUserAttributeKey.name.key] ??
          values[AuthUserAttributeKey.preferredUsername.key] ??
          user.username,
      isEmailVerified:
          values[AuthUserAttributeKey.emailVerified.key]?.toLowerCase() == 'true',
      isDemoAccount: false,
    );
  }

  Future<void> _saveTokens(AuthSession session) async {
    if (session is! CognitoAuthSession) return;
    final tokens = session.userPoolTokensResult.value;
    await _storage.saveSession(
      accessToken: tokens.accessToken.raw,
      idToken: tokens.idToken.raw,
    );
  }
}

final cognitoAuthServiceProvider = Provider<CognitoAuthService>((ref) {
  return CognitoAuthService(storage: ref.watch(secureStorageProvider));
});
