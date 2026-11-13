import 'package:mobile/core/error/failure.dart';

/// Outcome of an operation that can fail in an expected way.
///
/// Repositories and use cases return it, so exceptions never cross layers.
sealed class Result<T> {
  const Result();

  /// Creates a successful result.
  const factory Result.success(T value) = Success<T>;

  /// Creates a failed result.
  const factory Result.failure(Failure failure) = Err<T>;

  bool get isSuccess => this is Success<T>;

  /// The value when successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure when failed, otherwise `null`.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Transforms the value, keeping a failure as it is.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result<R>.success(transform(value)),
    Err<T>(:final failure) => Result<R>.failure(failure),
  };

  /// Chains another operation that can fail.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Success<T>(:final value) => transform(value),
    Err<T>(:final failure) => Result<R>.failure(failure),
  };

  /// Folds both cases into one value.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => switch (this) {
    Success<T>(value: final v) => success(v),
    Err<T>(failure: final f) => failure(f),
  };
}

/// A successful [Result].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

/// A failed [Result].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
