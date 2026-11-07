import 'package:amplify_flutter/amplify_flutter.dart';

import '../../../../core/storage/secure_storage_service.dart';
import '../models/auth_user_model.dart';
import '../services/cognito_auth_service.dart';

class AuthRepository {
  AuthRepository({
    required CognitoAuthService cognitoAuthService,
    required SecureStorageService secureStorage,
  }) : _cognito = cognitoAuthService,
       _secureStorage = secureStorage;

  final CognitoAuthService _cognito;
  final SecureStorageService _secureStorage;

  // Register a provider.
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) {
    return _cognito.signUp(
      fullName: fullName,
      email: email,
      mobile: mobile,
      password: password,
    );
  }

  // Verify the registration code.
  Future<SignUpResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) {
    return _cognito.confirmSignUp(
      email: email,
      confirmationCode: confirmationCode,
    );
  }

  // Sign in and store the access token when authentication completes.
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _cognito.signIn(email: email, password: password);

    if (result.isSignedIn) {
      final token = await _cognito.getAccessToken();

      if (token != null && token.isNotEmpty) {
        await _secureStorage.saveAccessToken(token);
      }
    }

    return result;
  }

  // Request password reset.
  Future<ResetPasswordResult> resetPassword({required String email}) {
    return _cognito.resetPassword(email: email);
  }

  // Confirm password reset.
  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) {
    return _cognito.confirmResetPassword(
      email: email,
      newPassword: newPassword,
      confirmationCode: confirmationCode,
    );
  }

  // Retrieve the current signed-in user.
  Future<AuthUserModel?> getCurrentUser() async {
    final signedIn = await _cognito.isSignedIn();

    if (!signedIn) {
      await _secureStorage.deleteAccessToken();
      return null;
    }

    final user = await _cognito.getCurrentUser();
    final attributes = await _cognito.getCurrentUserAttributes();
    return AuthUserModel(
      userId: user.userId,
      username: user.username,
      fullName: attributes['name'],
      email: attributes['email'] ?? user.username,
    );

  }

  // Sign out and clear the locally stored token.
  Future<void> signOut() async {
    try {
      await _cognito.signOut();
    } finally {
      await _secureStorage.deleteAccessToken();
    }
  }

  // Check if the user is signed in.
  Future<ResendSignUpCodeResult> resendSignUpCode({
    required String email,
  }) {
    return _cognito.resendSignUpCode(email: email);
  }
}
