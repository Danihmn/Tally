import 'package:mobile/core/error/failure.dart';

/// What a screen shows. One explicit state instead of loose booleans.
sealed class UiState<T> {
  const UiState();
}

/// Nothing loaded yet and nothing requested.
final class UiInitial<T> extends UiState<T> {
  const UiInitial();
}

/// First load in progress (the screen shows a skeleton).
final class UiLoading<T> extends UiState<T> {
  const UiLoading();
}

/// Data is ready.
final class UiSuccess<T> extends UiState<T> {
  const UiSuccess(this.data);

  final T data;
}

/// The request worked but there is nothing to show.
final class UiEmpty<T> extends UiState<T> {
  const UiEmpty();
}

/// The request failed and there is no data to keep on screen.
final class UiError<T> extends UiState<T> {
  const UiError(this.failure);

  final Failure failure;
}
