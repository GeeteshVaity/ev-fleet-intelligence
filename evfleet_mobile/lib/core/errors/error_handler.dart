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
        if (statusCode == 401 || statusCode == 403) {
          return AuthException(
            serverMessage ?? 'You are not authorized to do this.',
            code: '$statusCode',
            cause: error,
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

String? _serverMessage(Object? data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'] ?? data['error'];
    if (message != null && message.toString().isNotEmpty) {
      return message.toString();
    }
  }
  if (data is String && data.isNotEmpty && !data.startsWith('<')) return data;
  return null;
}
