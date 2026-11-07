import 'auth_user_model.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.pendingVerificationEmail,
    this.pendingPasswordResetEmail,
  });

  final AuthUserModel? user;
  final bool isLoading;
  final String? error;
  final String? pendingVerificationEmail;
  final String? pendingPasswordResetEmail;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUserModel? user,
    bool? isLoading,
    String? error,
    String? pendingVerificationEmail,
    String? pendingPasswordResetEmail,
    bool clearUser = false,
    bool clearError = false,
    bool clearPendingVerificationEmail = false,
    bool clearPendingPasswordResetEmail = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingVerificationEmail: clearPendingVerificationEmail
          ? null
          : (pendingVerificationEmail ?? this.pendingVerificationEmail),
      pendingPasswordResetEmail: clearPendingPasswordResetEmail
          ? null
          : (pendingPasswordResetEmail ?? this.pendingPasswordResetEmail),
    );
  }
}
