import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/error/failure.dart';

/// Turns every Dio error into a typed [Failure], stored in `DioException.error`.
///
/// The API answers errors as `{"detail": ...}`. `detail` is a fixed English
/// string for domain errors, but a LIST of `{loc, msg, type}` for request
/// validation (422). We read only the field names from the list and never
/// show server text to the user.
class ErrorInterceptor extends Interceptor {
  /// The `code` the API sends when there is no recurrence to provision from.
  static const noRecurrencesCode = 'NO_RECURRENCES';

  /// The `code` the API sends when a user's e-mail is already taken.
  static const emailAlreadyExistsCode = 'EMAIL_ALREADY_EXISTS';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: failureFrom(err)));
  }

  /// Maps a Dio error to a [Failure]. Public so it can be tested alone.
  static Failure failureFrom(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const NetworkFailure();
      case DioExceptionType.cancel:
        return const UnknownFailure();
      case DioExceptionType.unknown:
        return err.error is SocketException
            ? const NetworkFailure()
            : const UnknownFailure();
      case DioExceptionType.badResponse:
        return _fromResponse(err.response);
    }
  }

  static Failure _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    if (status == null) return const UnknownFailure();
    if (status == 401) return const UnauthorizedFailure();
    if (status == 404) return const NotFoundFailure();
    if (status == 409) {
      final data = response?.data;
      if (data is Map<String, dynamic> &&
          data['code'] == emailAlreadyExistsCode) {
        return const EmailAlreadyExistsFailure();
      }
      return const ConflictFailure();
    }
    if (status == 422) {
      final data = response?.data;
      if (data is Map<String, dynamic> && data['code'] == noRecurrencesCode) {
        return const NoRecurrencesFailure();
      }
      return ValidationFailure(fields: _invalidFields(data));
    }
    if (status >= 500) return const ServerUnavailableFailure();
    return const UnknownFailure();
  }

  /// Field names from a FastAPI validation error, for example `amount`.
  static List<String> _invalidFields(Object? data) {
    if (data is! Map<String, dynamic>) return const [];
    final detail = data['detail'];
    if (detail is! List<dynamic>) return const [];
    final fields = <String>[];
    for (final item in detail) {
      if (item is! Map<String, dynamic>) continue;
      final loc = item['loc'];
      if (loc is List<dynamic> && loc.isNotEmpty && loc.last is String) {
        fields.add(loc.last as String);
      }
    }
    return fields;
  }
}
