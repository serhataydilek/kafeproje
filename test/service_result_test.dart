import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/service_result.dart';

void main() {
  group('ServiceResultX', () {
    test('queuedOffline identifies the offline queue success message', () {
      final queued = ServiceResult<void>.success(
        message: ServiceResultMessages.offlineQueued,
      );
      final normal = ServiceResult<void>.success(message: 'ok');
      final failed = ServiceResult<void>.failure(
        message: ServiceResultMessages.offlineQueued,
      );

      expect(queued.queuedOffline, isTrue);
      expect(normal.queuedOffline, isFalse);
      expect(failed.queuedOffline, isFalse);
    });
  });
}
