import '../errors/app_exception.dart';

/// Explicit success/failure wrapper for data-layer calls that want to expose
/// results without throwing.
sealed class ApiResult<T> {
  const ApiResult();

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) => switch (this) {
    ApiSuccess<T>(:final data) => success(data),
    ApiFailure<T>(:final error) => failure(error),
  };

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  T? get valueOrNull => switch (this) {
    ApiSuccess<T>(:final data) => data,
    ApiFailure<T>() => null,
  };

  AppException? get errorOrNull => switch (this) {
    ApiSuccess<T>() => null,
    ApiFailure<T>(:final error) => error,
  };
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.error);
  final AppException error;
}

/// Runs [action] and captures any thrown error as an [ApiFailure].
Future<ApiResult<T>> guardApi<T>(Future<T> Function() action) async {
  try {
    return ApiSuccess(await action());
  } catch (error, stackTrace) {
    return ApiFailure(normalizeException(error, stackTrace));
  }
}
