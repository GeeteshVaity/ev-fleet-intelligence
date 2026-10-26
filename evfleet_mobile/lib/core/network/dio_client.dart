import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_interceptors.dart';

/// Provides the configured [Dio] client used by every remote data source.
///
/// The base URL comes from `--dart-define=API_BASE_URL=...` (see
/// [ApiConstants]); it is intentionally never hard-coded to a production
/// server. In demo mode the client is still constructed (so it is ready for
/// integration) but repositories do not call it.
final dioClientProvider = Provider<Dio>((ref) {
  return DioClient.build(secureStorage: ref.watch(secureStorageProvider));
});

abstract final class DioClient {
  static Dio build({required SecureStorageService secureStorage}) {
    final baseUrl = ApiConstants.effectiveApiBaseUrl;

    final dio = Dio(
      BaseOptions(
        // Placeholder only: requests are never issued until a real URL is set.
        baseUrl: baseUrl.isEmpty
            ? 'https://backend-not-configured.invalid'
            : baseUrl,
        connectTimeout: AppConstants.networkTimeout,
        receiveTimeout: AppConstants.networkTimeout,
        sendTimeout: AppConstants.networkTimeout,
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      ApiInterceptor(
        readAccessToken: secureStorage.readAccessToken,
        enableLogging: kDebugMode,
      ),
    );
    return dio;
  }
}
