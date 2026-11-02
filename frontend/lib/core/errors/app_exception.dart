/// Typed errors used across the application.
///
/// Repositories and services never leak raw `DioException`s to the UI;
/// everything is normalised into an [AppException] subclass by
/// `error_handler.dart`, so failure states are always explicit.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// User-presentable message (already safe to show in the UI).
  final String message;

  /// Optional machine-readable code (HTTP status, Cognito error code, ...).
  final String? code;

  /// Original error, kept for logging/debugging only.
  final Object? cause;

  @override
  String toString() => '$runtimeType${code == null ? '' : '($code)'}: $message';
}

/// No connection, timeout or DNS failure.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

/// The server answered with an error status.
final class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.code,
    super.cause,
  });

  final int? statusCode;
}

/// The response body could not be parsed into the expected model.
final class ParseException extends AppException {
  const ParseException(super.message, {super.cause});
}

/// Authentication/authorization failure (invalid credentials, expired token...).
final class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

/// The caller supplied invalid input; message explains what is wrong.
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

/// A required piece of configuration (backend URL, Cognito, maps API key...)
/// has not been provided yet, so the operation cannot honestly succeed.
final class NotConfiguredException extends AppException {
  const NotConfiguredException(super.message, {super.code});
}

/// A required device permission (e.g. location) was denied.
final class PermissionException extends AppException {
  const PermissionException(super.message, {super.code});
}
