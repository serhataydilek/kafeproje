import '../constants/error_codes.dart';

sealed class AsyncResult<T> {
  const AsyncResult();
}

final class AsyncLoading<T> extends AsyncResult<T> {
  const AsyncLoading({this.previous});

  final T? previous;
}

final class AsyncData<T> extends AsyncResult<T> {
  const AsyncData(this.value);

  final T value;
}

final class AsyncError<T> extends AsyncResult<T> {
  const AsyncError(
    this.code, {
    this.debugMessage,
    this.originalError,
    this.previous,
  });

  final AppErrorCode code;
  final String? debugMessage;
  final Object? originalError;
  final T? previous;
}

extension AsyncResultX<T> on AsyncResult<T> {
  bool get isLoading => this is AsyncLoading<T>;

  T? get dataOrNull => switch (this) {
        AsyncData<T>(value: final value) => value,
        AsyncLoading<T>(previous: final previous) => previous,
        AsyncError<T>(previous: final previous) => previous,
      };

  AsyncError<T>? get errorOrNull => switch (this) {
        AsyncError<T>() => this as AsyncError<T>,
        _ => null,
      };
}
