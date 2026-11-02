import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef AccessTokenReader = Future<String?> Function();

/// Global hook for authentication failures.
///
/// The app shell registers a handler that clears the local session and
/// returns the user to sign-in, so an expired or revoked Cognito access
/// token can never leave the UI calling a backend that keeps answering 401.
class SessionEvents {
  SessionEvents._();

  static void Function()? onUnauthorized;
}

/// Adds the Cognito access token to API requests without logging credentials.
class ApiInterceptor extends Interceptor {
  ApiInterceptor({required this.readAccessToken, this.enableLogging = false});

  final AccessTokenReader readAccessToken;
  final bool enableLogging;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (enableLogging) {
      debugPrint('-> ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enableLogging) {
      debugPrint('<- ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enableLogging) {
      debugPrint(
        '<- error ${err.response?.statusCode} '
        '${err.requestOptions.uri} '
        'type=${err.type} '
        'message=${err.message}',
      );
    }
    // 401 means the token is missing, expired or revoked: the local session
    // must be dropped. 403 is a permissions problem, not a session problem.
    if (err.response?.statusCode == 401) {
      SessionEvents.onUnauthorized?.call();
    }
    handler.next(err);
  }
}
