import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// ---------------------------------------------------------------------------
/// DEVELOPMENT-ONLY mock authentication.
///
/// This is NOT Amazon Cognito. It exists so the UI can be built and reviewed
/// before the AWS values are confirmed, and every screen that uses it shows a
/// "Demo auth" badge. Only non-sensitive flags are written to
/// SharedPreferences — never passwords and never tokens.
/// ---------------------------------------------------------------------------
abstract final class MockAuthKeys {
  static const String signedIn = 'mock_auth.signed_in';
  static const String userJson = 'mock_auth.user';
  static const String pendingEmail = 'mock_auth.pending_email';
  static const String pendingName = 'mock_auth.pending_name';
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository({SharedPreferences? storage}) : _injected = storage;

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  Future<SharedPreferences> get _prefs async =>
      _cached ??= _injected ?? await SharedPreferences.getInstance();

  Future<void> _delay() => Future<void>.delayed(AppConstants.mockLatency);

  @override
  bool get isMock => true;

  @override
  Future<AuthUser?> restoreSession() async {
    final prefs = await _prefs;
    if (prefs.getBool(MockAuthKeys.signedIn) != true) return null;
    final raw = prefs.getString(MockAuthKeys.userJson);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt local state: treat as signed out rather than crashing.
      return null;
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await _delay();
    if (password.length < 8) {
      // Demo rule so the failure path is real, not a fake success.
      throw const AuthException(
        'Email or password is incorrect.',
        code: 'demo_invalid_credentials',
      );
    }

    final prefs = await _prefs;
    final stored = prefs.getString(MockAuthKeys.userJson);
    String fullName = AppConstants.demoName;
    if (stored != null) {
      try {
        final previous = AuthUser.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        if (previous.email.toLowerCase() == email.toLowerCase()) {
          fullName = previous.fullName;
        }
      } catch (_) {
        /* fall through to the default name */
      }
    }

    final user = AuthUser(
      id: 'demo-user',
      email: email,
      fullName: fullName,
      isEmailVerified: true,
      createdAt: DateTime.now(),
      isDemoAccount: true,
    );
    await _persistSession(user);
    return user;
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _delay();
    if (password.length < 8) {
      throw const ValidationException('Password must be at least 8 characters');
    }
    final prefs = await _prefs;
    await prefs
      ..setString(MockAuthKeys.pendingEmail, email)
      ..setString(MockAuthKeys.pendingName, fullName);
  }

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    await _delay();
    if (code.trim() != AppConstants.demoVerificationCode) {
      throw ValidationException(
        'Wrong code. Demo mode accepts ${AppConstants.demoVerificationCode}.',
        code: 'demo_invalid_code',
      );
    }

    final prefs = await _prefs;
    final fullName =
        prefs.getString(MockAuthKeys.pendingName) ?? AppConstants.demoName;
    final user = AuthUser(
      id: 'demo-user',
      email: email,
      fullName: fullName,
      isEmailVerified: true,
      createdAt: DateTime.now(),
      isDemoAccount: true,
    );
    await prefs.remove(MockAuthKeys.pendingEmail);
    await prefs.remove(MockAuthKeys.pendingName);
    await _persistSession(user);
    return user;
  }

  @override
  Future<void> resendVerificationCode({required String email}) async {
    await _delay();
    // No email is actually sent in demo mode; the UI states this explicitly.
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _delay();
    if (email.trim().isEmpty) {
      throw const ValidationException('Email is required');
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _delay();
    if (code.trim() != AppConstants.demoVerificationCode) {
      throw ValidationException(
        'Wrong code. Demo mode accepts ${AppConstants.demoVerificationCode}.',
        code: 'demo_invalid_code',
      );
    }
    if (newPassword.length < 8) {
      throw const ValidationException('Password must be at least 8 characters');
    }
    // The new password is intentionally NOT persisted anywhere.
  }

  @override
  Future<void> signOut() async {
    final prefs = await _prefs;
    await prefs
      ..setBool(MockAuthKeys.signedIn, false)
      ..remove(MockAuthKeys.userJson);
  }

  @override
  Future<AuthUser> updateProfile(AuthUser user) async {
    await _delay();
    final prefs = await _prefs;
    await prefs.setString(MockAuthKeys.userJson, jsonEncode(user.toJson()));
    return user;
  }

  Future<void> _persistSession(AuthUser user) async {
    final prefs = await _prefs;
    await prefs
      ..setBool(MockAuthKeys.signedIn, true)
      ..setString(MockAuthKeys.userJson, jsonEncode(user.toJson()));
  }
}
