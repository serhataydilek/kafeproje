import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/models/async_result.dart';

void main() {
  group('AsyncResultX', () {
    test('isLoading reports loading state', () {
      const loading = AsyncLoading<int>();

      expect(loading.isLoading, isTrue);
      expect(const AsyncData<int>(1).isLoading, isFalse);
    });

    test('dataOrNull exposes previous data while loading or errored', () {
      const loading = AsyncLoading<int>(previous: 7);
      const error = AsyncError<int>(
        AppErrorCode.reviewSubmitFailed,
        previous: 9,
      );

      expect(loading.dataOrNull, 7);
      expect(error.dataOrNull, 9);
      expect(const AsyncData<int>(11).dataOrNull, 11);
    });

    test('errorOrNull only returns error states', () {
      const error = AsyncError<int>(AppErrorCode.reviewSubmitFailed);

      expect(error.errorOrNull, same(error));
      expect(const AsyncLoading<int>().errorOrNull, isNull);
      expect(const AsyncData<int>(3).errorOrNull, isNull);
    });
  });
}
