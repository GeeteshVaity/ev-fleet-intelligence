import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Converts any thrown object into an [AppException] with a message that is
/// safe to display. Never invents a success message for a failed operation.
AppException normalizeException(Object error, [StackTrace? stackTrace]) {
  if (error is AppException) return error;

  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _serverMessage(error.response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return NetworkException(
          'The request timed out. Please check your connection and try again.',
          code: 'timeout',
          cause: error,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return NetworkException(
          _connectionMessage(error),
          code: 'connection',
          cause: error,
        );
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          return AuthException(
            'Your session has expired. Please sign in again.',
            code: '401',
            cause: error,
          );
        }
        if (statusCode == 403) {
          return AuthException(
            serverMessage ??
                'You do not have permission to perform this action.',
            code: '403',
            cause: error,
          );
        }
        if (statusCode == 404) {
          return ServerException(
            serverMessage ??
                'That item could not be found. It may have been removed.',
            statusCode: statusCode,
            code: '404',
            cause: error,
          );
        }
        if (statusCode == 409) {
          return ServerException(
            serverMessage ??
                'The server rejected this request because the item changed. '
                    'The slot may already be booked — refresh and try again.',
            statusCode: statusCode,
            code: '409',
            cause: error,
          );
        }
        if (statusCode == 400 || statusCode == 422) {
          return ValidationException(
            serverMessage ?? 'The details sent were not valid. Please review them and try again.',
            code: '$statusCode',
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            serverMessage ??
                'The server had a problem. Please try again later.',
            statusCode: statusCode,
            code: '$statusCode',
            cause: error,
          );
        }
        return ServerException(
          serverMessage ?? 'The request could not be completed.',
          statusCode: statusCode,
          code: '$statusCode',
          cause: error,
        );
      case DioExceptionType.cancel:
        return NetworkException(
          'The request was cancelled.',
          code: 'cancelled',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return NetworkException(
          'The secure connection to the server could not be verified.',
          code: 'certificate',
          cause: error,
        );
    }
  }

  return NetworkException(
    'Something went wrong. Please try again.',
    cause: error,
  );
}

String _connectionMessage(DioException error) {
  final host = Uri.tryParse(error.requestOptions.baseUrl)?.host;
  if (host == 'localhost' || host == '10.0.2.2') {
    return 'Unable to reach the backend. On a physical Android device, '
        'launch the app with your computer LAN address, for example '
        'http://192.168.1.25:8080.';
  }
  return 'Unable to reach the server. Please check your connection.';
}

/// Convenience wrapper that only ever produces a displayable message.
String errorMessageOf(Object error) => normalizeException(error).message;

/// Reads a human-readable message from an error body.
///
/// Only `message` is trusted: Spring's `error` field carries the HTTP reason
/// phrase ("Conflict", "Bad Request"), which is not useful to a user. Bodies
/// that are HTML error pages or missing a message return null so the caller
/// falls back to a status-specific sentence. Stack traces and exception class
/// names are never surfaced.
String? _serverMessage(Object? data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String &&
        message.isNotEmpty &&
        !message.contains('Exception') &&
        !message.contains('\n')) {
      return message;
    }
  }
  if (data is String &&
      data.isNotEmpty &&
      !data.startsWith('<') &&
      !data.contains('Exception')) {
    return data;
  }
  return null;
}
