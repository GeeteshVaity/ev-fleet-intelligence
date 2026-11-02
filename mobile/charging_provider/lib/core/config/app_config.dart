class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const awsRegion = String.fromEnvironment(
    'AWS_REGION',
    defaultValue: 'ap-south-1',
  );

  static const cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
  );

  static const cognitoAppClientId = String.fromEnvironment(
    'COGNITO_APP_CLIENT_ID',
  );
}
