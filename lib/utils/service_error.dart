import 'dart:async';
import 'dart:io';

import '../constants/error_codes.dart';

enum ServiceErrorType {
  auth,
  cancelled,
  network,
  rateLimit,
  timeout,
  validation,
  conflict,
  notFound,
  parse,
  unavailable,
  unknown,
}

extension ServiceErrorTypeX on ServiceErrorType {
  bool get isTransient {
    return this == ServiceErrorType.network ||
        this == ServiceErrorType.rateLimit ||
        this == ServiceErrorType.timeout ||
        this == ServiceErrorType.unavailable;
  }
}

/// Typed service-layer exception used to preserve machine-readable failure
/// semantics instead of leaking fragile string matching into UI code.
class AppServiceException implements Exception {
  const AppServiceException({
    required this.message,
    required this.type,
    this.errorCode,
    this.cause,
  });

  const AppServiceException.auth(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.auth;

  const AppServiceException.cancelled(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.cancelled;

  const AppServiceException.network(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.network;

  const AppServiceException.timeout(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.timeout;

  const AppServiceException.rateLimit(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.rateLimit;

  const AppServiceException.validation(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.validation;

  const AppServiceException.conflict(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.conflict;

  const AppServiceException.notFound(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.notFound;

  const AppServiceException.parse(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.parse;

  const AppServiceException.unavailable(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.unavailable;

  const AppServiceException.unknown(
    this.message, {
    this.errorCode,
    this.cause,
  }) : type = ServiceErrorType.unknown;

  final String message;
  final ServiceErrorType type;
  final AppErrorCode? errorCode;
  final Object? cause;

  @override
  String toString() => message;
}

ServiceErrorType classifyServiceError(Object error) {
  if (error is AppServiceException) {
    return error.type;
  }
  if (error is TimeoutException) {
    return ServiceErrorType.timeout;
  }
  if (error is SocketException) {
    return ServiceErrorType.network;
  }

  final message = error.toString().toLowerCase();

  if (message.contains('timeout')) {
    return ServiceErrorType.timeout;
  }
  if (message.contains('socket') ||
      message.contains('network') ||
      message.contains('connection') ||
      message.contains('dns') ||
      message.contains('failed host lookup')) {
    return ServiceErrorType.network;
  }
  if (message.contains('cancel') || message.contains('aborted')) {
    return ServiceErrorType.cancelled;
  }
  if (message.contains('rate limit') ||
      message.contains('too many requests') ||
      message.contains('http 429')) {
    return ServiceErrorType.rateLimit;
  }
  if (message.contains('auth') ||
      message.contains('jwt') ||
      message.contains('permission') ||
      message.contains('unauthorized') ||
      message.contains('forbidden')) {
    return ServiceErrorType.auth;
  }
  if (message.contains('duplicate') ||
      message.contains('already exists') ||
      message.contains('unique')) {
    return ServiceErrorType.conflict;
  }
  if (message.contains('required') ||
      message.contains('invalid') ||
      message.contains('malformed') ||
      message.contains('check constraint')) {
    return ServiceErrorType.validation;
  }
  if (message.contains('not found') || message.contains('no rows')) {
    return ServiceErrorType.notFound;
  }
  if (message.contains('format') ||
      message.contains('json') ||
      message.contains('parse') ||
      message.contains('type')) {
    return ServiceErrorType.parse;
  }
  if (message.contains('not configured') ||
      message.contains('unavailable') ||
      message.contains('disabled')) {
    return ServiceErrorType.unavailable;
  }

  return ServiceErrorType.unknown;
}
