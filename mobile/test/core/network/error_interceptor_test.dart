import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/error_interceptor.dart';

DioException _bad(int status, [Object? data]) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

DioException _typed(DioExceptionType type, {Object? error}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  error: error,
);

void main() {
  group('ErrorInterceptor.failureFrom', () {
    test('maps_status_codes_to_typed_failures', () {
      expect(
        ErrorInterceptor.failureFrom(_bad(401)),
        const UnauthorizedFailure(),
      );
      expect(ErrorInterceptor.failureFrom(_bad(404)), const NotFoundFailure());
      expect(ErrorInterceptor.failureFrom(_bad(409)), const ConflictFailure());
      expect(
        ErrorInterceptor.failureFrom(_bad(503)),
        const ServerUnavailableFailure(),
      );
      expect(
        ErrorInterceptor.failureFrom(_bad(500)),
        const ServerUnavailableFailure(),
      );
      expect(ErrorInterceptor.failureFrom(_bad(418)), const UnknownFailure());
    });

    test('reads_field_names_from_a_422_whose_detail_is_a_list', () {
      final failure = ErrorInterceptor.failureFrom(
        _bad(422, {
          'detail': [
            {
              'loc': ['body', 'amount'],
              'msg': 'bad',
              'type': 'x',
            },
            {
              'loc': ['body', 'description'],
              'msg': 'bad',
              'type': 'x',
            },
          ],
        }),
      );
      expect(
        failure,
        const ValidationFailure(fields: ['amount', 'description']),
      );
    });

    test('a_422_with_the_no_recurrences_code_is_its_own_failure', () {
      final failure = ErrorInterceptor.failureFrom(
        _bad(422, {
          'detail': 'No recurrences to provision',
          'code': 'NO_RECURRENCES',
        }),
      );
      expect(failure, const NoRecurrencesFailure());
    });

    test('a_409_with_the_email_code_is_an_email_already_exists_failure', () {
      final failure = ErrorInterceptor.failureFrom(
        _bad(409, {
          'detail': 'Record already exists',
          'code': 'EMAIL_ALREADY_EXISTS',
        }),
      );
      expect(failure, const EmailAlreadyExistsFailure());
    });

    test('a_409_with_another_code_stays_a_conflict', () {
      final failure = ErrorInterceptor.failureFrom(
        _bad(409, {'detail': 'Record already exists', 'code': 'OTHER'}),
      );
      expect(failure, const ConflictFailure());
    });

    test('a_422_with_another_code_stays_a_validation_failure', () {
      final failure = ErrorInterceptor.failureFrom(
        _bad(422, {'detail': 'Invalid data', 'code': 'OTHER'}),
      );
      expect(failure, const ValidationFailure());
    });

    test('a_422_with_a_string_detail_has_no_fields', () {
      final failure = ErrorInterceptor.failureFrom(
        _bad(422, {'detail': 'Invalid data'}),
      );
      expect(failure, const ValidationFailure());
    });

    test('a_422_with_unexpected_body_does_not_crash', () {
      expect(
        ErrorInterceptor.failureFrom(_bad(422, 'oops')),
        const ValidationFailure(),
      );
      expect(
        ErrorInterceptor.failureFrom(
          _bad(422, {
            'detail': [
              1,
              'a',
              {'loc': <String>[]},
            ],
          }),
        ),
        const ValidationFailure(),
      );
    });

    test('maps_timeouts_and_connection_problems', () {
      expect(
        ErrorInterceptor.failureFrom(
          _typed(DioExceptionType.connectionTimeout),
        ),
        const TimeoutFailure(),
      );
      expect(
        ErrorInterceptor.failureFrom(_typed(DioExceptionType.receiveTimeout)),
        const TimeoutFailure(),
      );
      expect(
        ErrorInterceptor.failureFrom(_typed(DioExceptionType.connectionError)),
        const NetworkFailure(),
      );
      expect(
        ErrorInterceptor.failureFrom(
          _typed(DioExceptionType.unknown, error: const SocketException('x')),
        ),
        const NetworkFailure(),
      );
      expect(
        ErrorInterceptor.failureFrom(_typed(DioExceptionType.unknown)),
        const UnknownFailure(),
      );
    });
  });
}
