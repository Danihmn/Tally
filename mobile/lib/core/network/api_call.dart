import 'package:dio/dio.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';

/// Runs a remote call and returns a [Result]. Data sources use it so that a
/// raw `DioException` never goes up to repositories or ViewModels.
Future<Result<T>> apiCall<T>(Future<T> Function() request) async {
  try {
    return Result.success(await request());
  } on DioException catch (e) {
    final error = e.error;
    return Result.failure(error is Failure ? error : const UnknownFailure());
  } on FormatException {
    // The API sent a payload we cannot read.
    return const Result.failure(UnknownFailure());
  } on TypeError {
    return const Result.failure(UnknownFailure());
  }
}
