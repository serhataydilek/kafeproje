import '../constants/error_codes.dart';
import '../utils/service_error.dart';

abstract final class ServiceResultMessages {
  static const String offlineQueued = 'offline_queued';
}

sealed class ServiceResult<T> {
  const ServiceResult._({
    required this.ok,
    this.data,
    this.message,
    this.error,
    this.errorCode,
    this.errorType = ServiceErrorType.unknown,
  });

  factory ServiceResult.success({
    T? data,
    String? message,
    AppErrorCode? errorCode,
    ServiceErrorType errorType = ServiceErrorType.unknown,
  }) {
    return ServiceSuccess<T>(
      data: data,
      message: message,
      errorCode: errorCode,
      errorType: errorType,
    );
  }

  factory ServiceResult.failure({
    String? message,
    Object? error,
    AppErrorCode? errorCode,
    ServiceErrorType errorType = ServiceErrorType.unknown,
  }) {
    return ServiceFailure<T>(
      message: message,
      error: error,
      errorCode: errorCode,
      errorType: errorType,
    );
  }

  final bool ok;
  final T? data;
  final String? message;
  final Object? error;
  final AppErrorCode? errorCode;
  final ServiceErrorType errorType;
}

extension ServiceResultX<T> on ServiceResult<T> {
  bool get queuedOffline =>
      ok && message == ServiceResultMessages.offlineQueued;
}

final class ServiceSuccess<T> extends ServiceResult<T> {
  const ServiceSuccess({
    super.data,
    super.message,
    super.errorCode,
    super.errorType = ServiceErrorType.unknown,
  }) : super._(ok: true);
}

final class ServiceFailure<T> extends ServiceResult<T> {
  const ServiceFailure({
    super.message,
    super.error,
    super.errorCode,
    super.errorType = ServiceErrorType.unknown,
  }) : super._(ok: false);
}
