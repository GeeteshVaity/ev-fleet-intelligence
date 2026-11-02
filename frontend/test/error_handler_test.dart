import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evfleet_frontend/core/errors/app_exception.dart';
import 'package:evfleet_frontend/core/errors/error_handler.dart';

DioException _httpError(int status, Object? body) => DioException(
  requestOptions: RequestOptions(path: '/api/test'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/api/test'),
    statusCode: status,
    data: body,
  ),
);

void main() {
  group('normalizeException', () {
    test('maps 401 to an expired-session message without leaking details', () {
      final error = normalizeException(_httpError(401, {'error': 'Unauthorized'}));
      expect(error, isA<AuthException>());
      expect(error.message.toLowerCase(), contains('session'));
      expect(error.message.contains('Exception'), isFalse);
    });

    test('maps 409 conflict to actionable booking guidance', () {
      final error = normalizeException(
        _httpError(409, {'timestamp': '2026-10-28', 'error': 'Conflict'}),
      );
      expect(error, isA<ServerException>());
      expect((error as ServerException).statusCode, 409);
      // The Spring reason phrase is never shown to the user.
      expect(error.message, isNot('Conflict'));
      expect(error.message.toLowerCase(), contains('booked'));
    });

    test('uses the server message when one is provided', () {
      final error = normalizeException(
        _httpError(409, {'message': 'Station is already booked'}),
      );
      expect(error.message, 'Station is already booked');
    });

    test('never surfaces exception class names from error bodies', () {
      final error = normalizeException(
        _httpError(
          500,
          {'message': 'java.lang.NullPointerException: at com.evfleet.Foo'},
        ),
      );
      expect(error.message.contains('NullPointerException'), isFalse);
    });

    test('maps timeouts to a friendly message', () {
      final error = normalizeException(
        DioException(
          requestOptions: RequestOptions(path: '/api/test'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(error, isA<NetworkException>());
      expect(error.message.toLowerCase(), contains('timed out'));
    });

    test('maps 400 to a validation message', () {
      final error = normalizeException(
        _httpError(400, {'error': 'Bad Request'}),
      );
      expect(error, isA<ValidationException>());
      expect(error.message, isNot('Bad Request'));
    });
  });
}
