import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/services/reviews_service.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ReviewsService', () {
    test('fetchReviews deduplicates in-flight page requests', () async {
      final completer = Completer<List<Map<String, dynamic>>>();
      var loaderCount = 0;
      final service = ReviewsService(
        SupabaseClient('https://example.com', 'anon-key'),
        reviewRowsLoader: (
          String cafeId, {
          required int page,
          required int pageSize,
        }) {
          loaderCount += 1;
          return completer.future;
        },
      );

      final first = service.fetchReviews('cafe-1');
      final second = service.fetchReviews('cafe-1');

      completer.complete([
        {
          'id': 'review-1',
          'cafe_id': 'cafe-1',
          'user_id': 'user-1',
          'rating': 5,
          'content': 'Great coffee',
          'created_at': DateTime.utc(2026, 3, 28).toIso8601String(),
        },
      ]);

      final results = await Future.wait([first, second]);

      expect(loaderCount, 1);
      expect(results.every((result) => result.ok), isTrue);
      expect(results.first.data?.reviews, hasLength(1));
      expect(results.first.data?.hasMore, isFalse);
    });

    test('fetchReviews maps timeout failures consistently', () async {
      final service = ReviewsService(
        SupabaseClient('https://example.com', 'anon-key'),
        reviewRowsLoader: (
          String cafeId, {
          required int page,
          required int pageSize,
        }) async {
          throw const AppServiceException.timeout('reviews timed out');
        },
      );

      final result = await service.fetchReviews('cafe-1');

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.timeout);
      expect(result.errorCode, AppErrorCode.requestTimedOut);
    });

    test('submitReview rejects unauthenticated users before remote writes',
        () async {
      final service = ReviewsService(
        SupabaseClient('https://example.com', 'anon-key'),
      );

      final result = await service.submitReview(
        cafeId: 'cafe-1',
        rating: 5,
        content: 'Great coffee',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.auth);
      expect(result.errorCode, AppErrorCode.reviewAuthRequired);
    });

    test('submitReview rejects invalid ratings before remote writes', () async {
      final service = ReviewsService(
        SupabaseClient('https://example.com', 'anon-key'),
      );

      final result = await service.submitReview(
        cafeId: 'cafe-1',
        rating: 0,
        content: 'Great coffee',
      );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.validation);
      expect(result.errorCode, AppErrorCode.ratingOutOfRange);
    });
  });
}
