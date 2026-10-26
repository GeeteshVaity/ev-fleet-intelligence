import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API and backend configuration.
///
/// Nothing here is hard-coded to a production server or AWS account. Every
/// value is injected at build/run time with `--dart-define`, for example:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=https://api.example.com \
///   --dart-define=COGNITO_USER_POOL_ID=eu-west-1_XXXX \
///   --dart-define=AWS_REGION=eu-west-1 \
///   --dart-define=COGNITO_APP_CLIENT_ID=xxxxxxxx
/// ```
///
/// When `API_BASE_URL` is empty the app runs in **demo mode**: repositories
/// serve clearly-labelled in-memory sample data and no network request is
/// made. This is the default for UI development.
abstract final class ApiConstants {
  /// Base URL of the Spring Boot backend. Empty until configured.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

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

  /// True while no backend URL has been provided (demo mode).
  static bool get isMockBackend => apiBaseUrl.isEmpty;
  static bool get isBackendConfigured => apiBaseUrl.isNotEmpty;

  // --- Amazon Cognito (values come from the existing User Pool; never guessed)
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
