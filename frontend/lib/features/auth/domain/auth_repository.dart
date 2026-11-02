import 'auth_user.dart';

/// Contract for authentication.
///
/// Two implementations exist and are never mixed:
/// * `MockAuthRepository` — development-only, clearly labelled in the UI.
/// * `AuthRepositoryImpl` — delegates to [CognitoAuthService] once the
///   Cognito User Pool values are configured (see README checklist).
///
/// Passwords are only ever passed into a call; they are never persisted.
abstract interface class AuthRepository {
  /// Whether this repository is the development-only mock implementation.
  bool get isMock;

  /// Restores a previously stored session, or null when signed out.
  Future<AuthUser?> restoreSession();

  Future<AuthUser> signIn({required String email, required String password});

  /// Starts sign-up; the account then needs email verification.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// Confirms the email with a verification code.
  Future<void> confirmEmail({required String email, required String code});

  Future<void> resendVerificationCode({required String email});

  Future<void> requestPasswordReset({required String email});

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> signOut();

  Future<AuthUser> updateProfile(AuthUser user);
}
