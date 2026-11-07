
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class CognitoAuthService {
  // 1. Register a new provider.
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    return Amplify.Auth.signUp(
      username: email.trim(),
      password: password,
      options: SignUpOptions(
        userAttributes: {
          AuthUserAttributeKey.email: email.trim(),
          AuthUserAttributeKey.name: fullName.trim(),
          AuthUserAttributeKey.phoneNumber: _formatIndianMobile(mobile),
        },
      ),
    );
  }

  // Helper for Indian phone number formatting.
  String _formatIndianMobile(String mobile) {
    final value = mobile.trim();

    if (value.startsWith('+')) return value;

    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '+91$digits';
    }

    throw const FormatException(
      'Enter a valid 10-digit Indian mobile number.',
    );
  }

  // 2. Verify registration.
  Future<SignUpResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    return Amplify.Auth.confirmSignUp(
      username: email.trim(),
      confirmationCode: confirmationCode.trim(),
    );
  }

  // 3. Sign in.
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    return Amplify.Auth.signIn(
      username: email.trim(),
      password: password,
    );
  }

  // 4. Request password reset.
  Future<ResetPasswordResult> resetPassword({
    required String email,
  }) async {
    return Amplify.Auth.resetPassword(
      username: email.trim(),
    );
  }

  // 5. Confirm password reset.
  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    await Amplify.Auth.confirmResetPassword(
      username: email.trim(),
      newPassword: newPassword,
      confirmationCode: confirmationCode.trim(),
    );
  }

  // 6. Sign out.
  Future<void> signOut() async {
    await Amplify.Auth.signOut();
  }

  // 7. Check authentication session.
  Future<bool> isSignedIn() async {
    final session = await Amplify.Auth.fetchAuthSession();
    return session.isSignedIn;
  }

  // 8. Get current Cognito user.
  Future<AuthUser> getCurrentUser() async {
    return Amplify.Auth.getCurrentUser();
  }

  // 9. Retrieve Cognito access token.
  Future<String?> getAccessToken() async {
    final session =
        await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

    if (!session.isSignedIn) {
      return null;
    }

    final tokens = session.userPoolTokensResult.value;
    return tokens.accessToken.raw;
  }

  // 10. Resend confirmation code.
  Future<ResendSignUpCodeResult> resendSignUpCode({
    required String email,
  }) {
    return Amplify.Auth.resendSignUpCode(
      username: email.trim(),
    );
  }

  // 11. Retrieve current user's Cognito attributes.
  Future<Map<String, String>> getCurrentUserAttributes() async {
    final attributes = await Amplify.Auth.fetchUserAttributes();

    return {
      for (final attribute in attributes)
        attribute.userAttributeKey.key: attribute.value,
    };
  }
}
