import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth_state_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_providers.dart';

class AuthController extends AsyncNotifier<AuthState> {
  late AuthRepository _repository;

  @override
  Future<AuthState> build() async {
    _repository = ref.watch(authRepositoryProvider);

    // Restore the existing Cognito session when the app opens.
    final user = await _repository.getCurrentUser();

    return AuthState(user: user);
  }

  AuthState get _currentState =>
    state.asData?.value ?? const AuthState();

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  // REGISTER
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      await _repository.signUp(
        fullName: fullName,
        email: email,
        mobile: mobile,
        password: password,
      );

      state = AsyncData(
        previous.copyWith(
          isLoading: false,
          pendingVerificationEmail: email.trim(),
          clearError: true,
        ),
      );

      return true;
    } catch (error) {
      state = AsyncData(
        previous.copyWith(isLoading: false, error: _errorMessage(error)),
      );

      return false;
    }
  }

  // VERIFY EMAIL
  Future<bool> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      await _repository.confirmSignUp(
        email: email,
        confirmationCode: confirmationCode,
      );

      state = AsyncData(
        previous.copyWith(
          isLoading: false,
          clearPendingVerificationEmail: true,
          clearError: true,
        ),
      );

      return true;
    } catch (error) {
      state = AsyncData(
        previous.copyWith(isLoading: false, error: _errorMessage(error)),
      );

      return false;
    }
  }

  // LOGIN
  Future<bool> signIn({required String email, required String password}) async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      final result = await _repository.signIn(email: email, password: password);

      if (!result.isSignedIn) {
        state = AsyncData(
          previous.copyWith(
            isLoading: false,
            error: 'Additional Cognito sign-in verification is required.',
          ),
        );

        return false;
      }

      final user = await _repository.getCurrentUser();

      if (user == null) {
        throw Exception('Could not retrieve the authenticated user.');
      }

      state = AsyncData(AuthState(user: user));

      return true;
    } catch (error) {
      state = AsyncData(
        previous.copyWith(isLoading: false, error: _errorMessage(error)),
      );

      return false;
    }
  }

  // REQUEST PASSWORD RESET
  Future<bool> resetPassword({required String email}) async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      await _repository.resetPassword(email: email);

      state = AsyncData(
        previous.copyWith(
          isLoading: false,
          pendingPasswordResetEmail: email.trim(),
          clearError: true,
        ),
      );

      return true;
    } catch (error) {
      state = AsyncData(
        previous.copyWith(isLoading: false, error: _errorMessage(error)),
      );

      return false;
    }
  }

  // CONFIRM PASSWORD RESET
  Future<bool> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      await _repository.confirmResetPassword(
        email: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );

      state = AsyncData(
        previous.copyWith(
          isLoading: false,
          clearPendingPasswordResetEmail: true,
          clearError: true,
        ),
      );

      return true;
    } catch (error) {
      state = AsyncData(
        previous.copyWith(isLoading: false, error: _errorMessage(error)),
      );

      return false;
    }
  }

  // RESEND VERIFICATION CODE
  Future<bool> resendSignUpCode({
    required String email,
  }) async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(
      isLoading: true,
      clearError: true,
    ));

    try {
      await _repository.resendSignUpCode(email: email);

      state = AsyncData(previous.copyWith(
        isLoading: false,
        clearError: true,
      ));

      return true;
    } catch (error) {
      state = AsyncData(previous.copyWith(
        isLoading: false,
        error: _errorMessage(error),
      ));

      return false;
    }
  }

  // LOGOUT
  Future<void> signOut() async {
    final previous = _currentState;

    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      await _repository.signOut();

      state = const AsyncData(AuthState());
    } catch (error) {
      state = AsyncData(
        previous.copyWith(isLoading: false, error: _errorMessage(error)),
      );
    }
  }
}
