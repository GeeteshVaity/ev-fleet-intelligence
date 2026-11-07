class AppConfig {
  AppConfig._();

  // Backend configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Backward-compatible alias
  static const String baseUrl = apiBaseUrl;

  // AWS Cognito configuration
  static const String cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
  );

  static const String cognitoAppClientId = String.fromEnvironment(
    'COGNITO_APP_CLIENT_ID',
  );

  static const String awsRegion = String.fromEnvironment('AWS_REGION');

  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 20);

  static const Duration receiveTimeout = Duration(seconds: 20);
}