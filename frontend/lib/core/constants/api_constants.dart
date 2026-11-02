import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API and backend configuration.
///
/// Every value has a shipped default (the deployed demo backend and its
/// Cognito user pool) and can be overridden at build/run time with
/// `--dart-define`, for example:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=https://api.example.com \
///   --dart-define=COGNITO_USER_POOL_ID=eu-west-1_XXXX \
///   --dart-define=AWS_REGION=eu-west-1 \
///   --dart-define=COGNITO_APP_CLIENT_ID=xxxxxxxx
/// ```
///
/// Sample data is served **only** when the build explicitly opts in with
/// `--dart-define=DEMO_MODE=true`. A network failure never falls back to
/// sample data: it surfaces as an error state in the UI.
abstract final class ApiConstants {
  /// Base URL of the Spring Boot backend.
  ///
  /// Defaults to the deployed AWS backend so a plain `flutter run` talks to
  /// the real API instead of silently serving demo data. Override with
  /// `--dart-define=API_BASE_URL=...` for local development.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://3.111.39.106:8080',
  );

  /// Explicit opt-in for the in-memory demo dataset. Never implied by a
  /// failed request or a missing URL.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  /// URL used by the HTTP client for the current platform.
  ///
  /// Android emulators expose the host machine through 10.0.2.2. Keeping
  /// localhost in the run command is convenient for desktop and web, but it
  /// would otherwise point back at the emulator when the app runs on Android.
  static String get effectiveApiBaseUrl {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return apiBaseUrl;
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || (uri.host != 'localhost' && uri.host != '127.0.0.1')) {
      return apiBaseUrl;
    }

    return uri.replace(host: '10.0.2.2').toString();
  }

  /// True only when the demo dataset was explicitly requested.
  static bool get isMockBackend => demoMode;
  static bool get isBackendConfigured => !demoMode && apiBaseUrl.isNotEmpty;

  // --- Amazon Cognito (values come from the existing User Pool; never
  // guessed and never committed). Inject them at build/run time:
  //
  //   --dart-define=COGNITO_USER_POOL_ID=ap-south-1_5Kd0M6Ks1 \
  //   --dart-define=AWS_REGION=ap-south-1 \
  //   --dart-define=COGNITO_APP_CLIENT_ID=cu99248mdofvm2p56lccnit0h
  //
  // Without them the app still builds and connects to the backend, but
  // sign-in and registration fail loudly with a configuration error instead
  // of silently falling back to a local, API-incapable session.
  static const String cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
  );
  static const String cognitoRegion = String.fromEnvironment('AWS_REGION');
  static const String cognitoAppClientId = String.fromEnvironment(
    'COGNITO_APP_CLIENT_ID',
  );
  static const String cognitoRedirectUri = String.fromEnvironment(
    'COGNITO_REDIRECT_URI',
  );

  /// True only when every required Cognito value has been provided.
  static bool get isCognitoConfigured =>
      cognitoUserPoolId.isNotEmpty &&
      cognitoRegion.isNotEmpty &&
      cognitoAppClientId.isNotEmpty;

  /// REST paths expected from the Spring Boot API (used by remote data sources).
  static const String stationsPath = '/api/stations';
  static const String bookingsPath = '/api/bookings';
  static const String vehiclesPath = '/api/vehicles';
  static const String sessionsPath = '/api/sessions';
  static const String notificationsPath = '/api/notifications';
  static const String profilePath = '/api/users/me';
}

/// Riverpod-accessible view of [ApiConstants.isMockBackend] so widgets can
/// label demo data without importing raw constants everywhere.
final isDemoDataProvider = Provider<bool>((ref) => ApiConstants.isMockBackend);
