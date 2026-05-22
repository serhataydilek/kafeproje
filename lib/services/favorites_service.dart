import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/network_config.dart';
import '../utils/app_logger.dart';
import '../utils/inflight_request_registry.dart';
import '../utils/service_error.dart';

/// Manages user favorites with Supabase as source of truth and Hive as
/// local cache / offline support.
///
/// Favorites are stored in the `user_favorites` table as (user_id, cafe_id)
/// pairs. The `cafes.favorite_count` column is kept in sync via a Postgres
/// trigger (see migration SQL).
class FavoritesService {
  FavoritesService(this._client);

  final SupabaseClient _client;

  final InflightRequestRegistry<List<String>?> _inflightLoad =
      InflightRequestRegistry<List<String>?>();

  /// Fetches all cafe IDs favorited by [userId] from Supabase.
  ///
  /// Returns `null` when the remote read fails so callers can preserve
  /// local cached favorites instead of treating failures as an empty list.
  Future<List<String>?> loadFavorites(String userId) async {
    return _inflightLoad.run('load-$userId', () async {
      try {
        final data = await _client
            .from('user_favorites')
            .select('cafe_id')
            .eq('user_id', userId)
            .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);

        return (data as List)
            .map((row) => (row as Map<String, dynamic>)['cafe_id'] as String)
            .toList(growable: false);
      } catch (error, stackTrace) {
        AppLogger.warn(
          'FavoritesService.loadFavorites failed for userId=$userId',
          key: 'favorites-load-$userId',
        );
        AppLogger.error(
          'FavoritesService.loadFavorites error',
          error: error,
          stackTrace: stackTrace,
          key: 'favorites-load-error',
        );
        // Return null so the caller can keep using the Hive cache.
        return null;
      }
    });
  }

  /// Adds a cafe to favorites. Returns `true` on success, `false` on failure.
  ///
  /// Uses `INSERT ... ON CONFLICT DO NOTHING` to be idempotent (prevents
  /// duplicate rows from the same user).
  Future<bool> addFavorite(String userId, String cafeId) async {
    try {
      await _client.from('user_favorites').upsert(
        {'user_id': userId, 'cafe_id': cafeId},
        onConflict: 'user_id,cafe_id',
        ignoreDuplicates: true,
      ).timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'FavoritesService.addFavorite failed userId=$userId cafeId=$cafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'favorites-add-$cafeId',
      );
      return false;
    }
  }

  /// Removes a cafe from favorites. Returns `true` on success.
  Future<bool> removeFavorite(String userId, String cafeId) async {
    try {
      await _client
          .from('user_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('cafe_id', cafeId)
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'FavoritesService.removeFavorite failed userId=$userId cafeId=$cafeId',
        error: error,
        stackTrace: stackTrace,
        key: 'favorites-remove-$cafeId',
      );
      return false;
    }
  }

  /// Returns whether [cafeId] is currently favorited by [userId].
  Future<bool> isFavorited(String userId, String cafeId) async {
    try {
      final data = await _client
          .from('user_favorites')
          .select('cafe_id')
          .eq('user_id', userId)
          .eq('cafe_id', cafeId)
          .maybeSingle()
          .timeout(NetworkTimeoutConfig.supabaseDataRequestTimeout);
      return data != null;
    } catch (_) {
      return false;
    }
  }

  ServiceErrorType classifyError(Object error) => classifyServiceError(error);
}
