import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_handler.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

/// Authentication status driving the route guards.
enum AuthStatus {
  /// Session restore in progress (splash screen).
  restoring,

  unauthenticated,
  authenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.user,
    this.isBusy = false,
    this.errorMessage,
    this.infoMessage,
    this.pendingVerificationEmail,
  });

  final AuthStatus status;
  final AuthUser? user;

  /// True while an auth operation (sign-in, sign-up...) is running.
  final bool isBusy;

  /// Non-null when the last operation failed; shown as an inline error.
  final String? errorMessage;

  /// Non-null for operations that need a non-error follow-up hint.
  final String? infoMessage;

  /// Set after sign-up while the email still needs verification.
  final String? pendingVerificationEmail;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAuthenticatedMock => user?.isDemoAccount ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isBusy,
    String? errorMessage,
    String? infoMessage,
    String? pendingVerificationEmail,
    bool clearError = false,
    bool clearInfo = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      pendingVerificationEmail:
          pendingVerificationEmail ?? this.pendingVerificationEmail,
    );
  }
}

/// Development seam around [AuthRepository]: restores the session, exposes
/// explicit busy/error states and never reports success for a failed call.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository = ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(_restoreSession);
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _repository.restoreSession();
      state = AuthState(
        status: user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: user,
      );
    } catch (_) {
      // A failed restore must not lock the user out of sign-in.
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  void clearMessages() {
    if (state.errorMessage != null || state.infoMessage != null) {
      state = state.copyWith(clearError: true, clearInfo: true);
    }
  }

  Future<bool> _run(Future<AuthUser?> Function() action) async {
    state = state.copyWith(isBusy: true, clearError: true, clearInfo: true);
    try {
      final user = await action();
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
      return true;
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _messageOf(error));
      return false;
    }
  }

  Future<bool> _runSilent(Future<void> Function() action) async {
    state = state.copyWith(isBusy: true, clearError: true, clearInfo: true);
    try {
      await action();
      state = state.copyWith(isBusy: false);
      return true;
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _messageOf(error));
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => _repository.signIn(email: email, password: password));
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final ok = await _runSilent(
      () => _repository.signUp(
        fullName: fullName,
        email: email,
        password: password,
      ),
    );
    if (ok) {
      state = state.copyWith(
        pendingVerificationEmail: email,
        infoMessage: 'We sent a verification code to $email.',
      );
    }
    return ok;
  }

  Future<bool> confirmEmail({required String email, required String code}) {
    return _runSilent(
      () => _repository.confirmEmail(email: email, code: code),
    );
  }

  Future<bool> resendVerificationCode({required String email}) async {
    final ok = await _runSilent(
      () => _repository.resendVerificationCode(email: email),
    );
    if (ok) {
      state = state.copyWith(
        clearError: true,
        infoMessage:
            'A new code would be sent to $email in production — demo mode '
            'accepts the documented demo code.',
      );
    }
    return ok;
  }

  Future<bool> requestPasswordReset({required String email}) async {
    final ok = await _runSilent(
      () => _repository.requestPasswordReset(email: email),
    );
    if (ok) {
      state = state.copyWith(
        clearError: true,
        infoMessage:
            'If an account exists for $email, a reset code is on '
            'its way.',
      );
    }
    return ok;
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _runSilent(
      () => _repository.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repository.signOut();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    String? phoneNumber,
  }) async {
    final user = state.user;
    if (user == null) return false;

    return _runSilent(() async {
      final updated = await _repository.updateProfile(
        user.copyWith(
          fullName: fullName,
          phoneNumber: phoneNumber,
          clearPhone: phoneNumber == null || phoneNumber.isEmpty,
        ),
      );
      state = state.copyWith(user: updated, isBusy: false);
    });
  }

  String _messageOf(Object error) => errorMessageOf(error);
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// True while the app uses the development-only mock auth implementation.
final authIsMockProvider = Provider<bool>(
  (ref) => ref.watch(authRepositoryProvider).isMock,
);
