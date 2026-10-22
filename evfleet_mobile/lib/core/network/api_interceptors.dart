import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Reads the current JWT access token from secure storage.
typedef AccessTokenReader = Future<String?> Function();

/// Attaches the bearer token to outgoing API calls and (optionally) logs
/// requests in debug mode. Tokens are read from secure storage only —
/// they are never written to shared preferences.
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
      debugPrint('→ ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enableLogging) {
      debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enableLogging) {
      debugPrint(
        '← error ${err.response?.statusCode} ${err.requestOptions.uri}',
      );
    }
    handler.next(err);
  }
}
