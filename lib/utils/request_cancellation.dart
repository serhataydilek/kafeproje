import 'service_error.dart';

class RequestCancellationToken {
  RequestCancellationToken._();

  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void throwIfCancelled() {
    if (!_isCancelled) {
      return;
    }
    throw AppServiceException.cancelled(
      _reason ?? 'Request was cancelled.',
    );
  }
}

class RequestCancellationController {
  RequestCancellationController({
    String? defaultReason,
  }) : _defaultReason = defaultReason;

  final String? _defaultReason;
  final RequestCancellationToken _token = RequestCancellationToken._();

  RequestCancellationToken get token => _token;

  bool get isCancelled => _token.isCancelled;

  void cancel([String? reason]) {
    if (_token._isCancelled) {
      return;
    }
    _token._isCancelled = true;
    _token._reason = reason ?? _defaultReason ?? 'Request was cancelled.';
  }
}
