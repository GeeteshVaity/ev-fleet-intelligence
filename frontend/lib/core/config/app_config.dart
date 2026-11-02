import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';

/// A single missing or invalid build-time configuration value.
///
/// The app never guesses an AWS resource identifier. When a required value is
/// absent, startup surfaces it here so the developer sees exactly which key is
/// missing and where to obtain it, instead of hitting a vague network or
/// "not authorized" error at sign-in time.
@immutable
class ConfigIssue {
  const ConfigIssue({
    required this.key,
    required this.problem,
    required this.source,
  });

  /// The `--dart-define` key that is missing or invalid.
  final String key;

  /// What is wrong with the value.
  final String problem;

  /// Where the developer obtains the real value (AWS Console location).
  final String source;

  @override
  bool operator ==(Object other) =>
      other is ConfigIssue && other.key == key && other.problem == problem;

  @override
  int get hashCode => Object.hash(key, problem);
}

/// Validation of the public, client-side configuration.
///
/// Only values that are safe to ship in a mobile binary live here:
/// the API origin, the AWS region, the Cognito User Pool ID and the Cognito
/// app client ID. There is no database password, no AWS secret access key and
/// no Cognito app client secret — those must never exist in the client.
///
/// Values are injected at build/run time:
///
/// ```sh
/// flutter run --dart-define-from-file=.env
/// ```
///
/// Every required key is reported in [issues]; nothing is silently defaulted
/// except the sample API origin in [ApiConstants], which is overridden by any
/// real deployment.
abstract final class AppConfig {
  /// True when the build opted into the in-memory demo dataset.
  static bool get demoMode => ApiConstants.isMockBackend;

  /// Every configuration problem that would prevent real authentication.
  ///
  /// In demo mode the Cognito keys are not needed, because sign-in is served
  /// by the in-memory auth repository rather than the User Pool.
  static List<ConfigIssue> get issues {
    final issues = <ConfigIssue>[];

    // --- API origin -------------------------------------------------------
    if (ApiConstants.apiBaseUrl.trim().isEmpty) {
      issues.add(
        const ConfigIssue(
          key: 'API_BASE_URL',
          problem: 'No backend URL was provided.',
          source: 'Your Spring Boot deployment (Elastic IP or ALB DNS name).',
        ),
      );
    } else {
      final uri = Uri.tryParse(ApiConstants.effectiveApiBaseUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        issues.add(
          ConfigIssue(
            key: 'API_BASE_URL',
            problem:
                'Not a valid absolute URL: "${ApiConstants.apiBaseUrl}". '
                'Expected e.g. https://api.example.com',
            source: 'Your Spring Boot deployment origin.',
          ),
        );
      } else if (uri.scheme != 'https' &&
          !demoMode &&
          kReleaseMode &&
          !_isLoopback(uri.host)) {
        // Release builds must never send credentials over plaintext HTTP.
        issues.add(
          ConfigIssue(
            key: 'API_BASE_URL',
            problem:
                'Release builds require HTTPS, got "${uri.scheme}". '
                'Put the API behind TLS (ALB/CloudFront) or use a https URL.',
            source: 'AWS Certificate Manager + ALB/CloudFront in front of EC2.',
          ),
        );
      }
    }

    if (demoMode) return issues;

    // --- Cognito ----------------------------------------------------------
    if (ApiConstants.cognitoRegion.trim().isEmpty) {
      issues.add(
        const ConfigIssue(
          key: 'AWS_REGION',
          problem: 'Cognito region is not set.',
          source:
              'AWS Console → the region shown in the top-right selector when '
              'the User Pool is open (e.g. ap-south-1).',
        ),
      );
    }
    if (ApiConstants.cognitoUserPoolId.trim().isEmpty) {
      issues.add(
        const ConfigIssue(
          key: 'COGNITO_USER_POOL_ID',
          problem: 'Cognito User Pool ID is not set.',
          source:
              'Cognito → User pools → your pool → Overview → "User pool ID".',
        ),
      );
    }
    if (ApiConstants.cognitoAppClientId.trim().isEmpty) {
      issues.add(
        const ConfigIssue(
          key: 'COGNITO_APP_CLIENT_ID',
          problem: 'Cognito app client ID is not set.',
          source:
              'Cognito → User pools → your pool → App integration → '
              'App clients → "Client ID". Must be an app client '
              'WITHOUT a client secret (public mobile client).',
        ),
      );
    }
    return issues;
  }

  /// True when every required value is present and well formed.
  static bool get isReady => issues.isEmpty;

  /// One-line summary for logs. Never includes tokens or secrets.
  static String get summary {
    if (isReady) {
      return demoMode
          ? 'Configuration OK (DEMO_MODE=true, no AWS calls).'
          : 'Configuration OK.';
    }
    final keys = issues.map((i) => i.key).join(', ');
    return 'Missing or invalid configuration: $keys';
  }

  static bool _isLoopback(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
}
