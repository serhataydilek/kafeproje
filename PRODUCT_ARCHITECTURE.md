# KafeProje Technical Architecture & Release Readiness

## 1. Executive Summary

KafeProje is a Flutter cafe discovery app for Istanbul. The current architecture is a client app backed by Supabase for auth, profile/cafe/review/favorite data and Google Places for live cafe discovery, place details, and photo metadata.

Current source-of-truth decisions:

- **Supabase is the source of truth for app-managed data:** auth, profiles, favorites, reviews, admin-created/edited cafes, soft deletes, and admin authorization.
- **Google Places is the source of truth for live external place metadata:** nearby search, text search, place details, Google ratings, Google review counts, coordinates, opening hours, and photo references.
- **`CafeRepository` is the client-side integration boundary:** it merges Google Places results with Supabase overlays, applies delete blocks, manages memory/local caches, and deduplicates in-flight requests.
- **Riverpod state notifiers are UI state owners:** widgets should not own remote-fetch or mutation rules directly.
- **Supabase RLS and SQL are the authoritative security boundary:** route guards and client validation are UX controls only.

Current release posture:

- The repo has focused tests for routing, cache behavior, merge/deletion behavior, classifier rules, favorites, compare, reviews, offline queue, Supabase services, rate limiting, and startup behavior.
- Release readiness depends on applying all Supabase migrations, passing `app_security_readiness()`, running malicious-client RLS checks, and confirming Google API key restrictions.
- Review mutation rate limiting now has a backend trigger in `supabase/cafe_reviews_rate_limit.sql`; the previous client-only cooldown was not enough as an abuse boundary.

Cross-check corrections from the previous architecture writeup:

| Previous wording | Correction from current repo |
| --- | --- |
| "Firebase diagnostics and analytics" | `lib/main.dart` initializes Firebase Crashlytics. `lib/services/analytics_service.dart` now provides a minimal Firebase Analytics implementation for release builds and a debug implementation for dev/test. |
| "Offline queueing handles retryable user work" | Confirmed for review submissions and profile updates in `lib/services/offline_queue.dart`. Favorites are local-first/optimistic and old favorite queue entries are drained without retrying remote sync. |
| "Backend rate limiting exists" | Now true for review mutations via `supabase/cafe_reviews_rate_limit.sql`. Google Places throttling remains client-side plus provider quota only. |
| "Deleted cafes are suppressed" | Confirmed in both `CafeMergePolicy` and `CafeRepository` through place ID, canonical identity, and fallback name/coordinate block keys. |
| "Friends/social layer" | Current implementation uses `NoopFriendsService`; real friend backend is not confirmed in current repo. |

## 2. Product Scope

Current implementation:

- Cafe discovery in Istanbul through Home, Explore, and Map flows.
- Search/filter/sort over loaded cafe data.
- Map discovery with radius presets and persisted map view state.
- Cafe detail flow with Google/Supabase detail merge and review display.
- Compare flow for up to four cafes.
- Favorites flow with Supabase as remote source and Hive as local cache.
- Reviews with rating, community fields, content moderation, duplicate-text checks, local cooldown, offline queueing, and backend mutation cooldown.
- Profile/auth flow using Supabase Auth and profile records.
- Admin cafe management for add/edit/soft-delete/restore/list/detail flows.
- Offline-tolerant behavior through Hive caches, cached startup hydration, connectivity-aware refresh, and offline queues for supported mutations.
- Security readiness checks through `public.app_security_readiness()` and app startup/admin mutation gates.

Not confirmed in current repo:

- A backend proxy/Edge Function for Google Places.
- A real friends backend; social providers currently use a no-op service.
- Automated end-to-end release smoke tests against a live Supabase project.

## Current Implementation Status

| Feature | Status | Notes |
| --- | --- | --- |
| Crash reporting | Implemented | `lib/main.dart` initializes Firebase and `FirebaseCrashlytics.instance`; `AppLogger.configureCrashlytics()` wires app logging/error forwarding after initialization. |
| Production analytics | Implemented | `firebase_analytics` is installed. `analyticsServiceProvider` returns `FirebaseAnalyticsService` in release and `DebugAnalyticsService` in non-release builds. Events currently wired: `app_open`, `cafe_detail_opened`, `favorite_toggled`, `compare_added`, `compare_removed`, `review_submitted`, `review_deleted`, `map_radius_changed`, `search_performed`, `filter_applied`, `admin_cafe_added`, `admin_cafe_updated`, `admin_cafe_deleted`, `admin_cafe_restored`. |
| Friends backend | Not implemented | Out of current release scope. Current friend/social implementation uses `NoopFriendsService` and should remain hidden/limited unless a real backend is added. |
| Google Places proxy / Edge Function | Not implemented | Future option; current release relies on client-side caches/throttles plus Google API key restrictions, quota ceilings, and billing alerts. |
| Automated live Supabase smoke tests | Not implemented | Current release uses local tests plus manual smoke/RLS checklist. Do not treat automated live Supabase coverage as present. |

## 3. Platform & Layer Architecture

| Layer | Responsibility | Important files/classes | Should not contain |
| --- | --- | --- | --- |
| `lib/main.dart` | Bootstraps environment, Crashlytics, encrypted local storage, Supabase, provider overrides, theme/localization/router. | `main()`, `LocalStorageService.open()`, `Supabase.initialize()`, `AppLogger.configureCrashlytics()` | Feature business logic, cafe merge rules, direct screen-level mutation code. |
| `lib/screens` | Route-level UI for auth, home, explore, map, detail, favorites, compare, profile, settings, admin, cafe add/edit, filters. | `HomeScreen`, `ExploreScreen`, `MapScreen`, `CafeDetailScreen`, `FavoritesScreen`, `CompareScreen`, `AdminScreen`, `CafeAddScreen`, `CafeEditScreen`, `AuthScreen`, `ProfileScreen`, `SettingsScreen` | Raw Supabase/HTTP calls, cache mutation rules, classifier logic, SQL/security assumptions. |
| `lib/widgets` | Reusable UI components and screen sections. | `widgets/cafes/*`, `widgets/admin/*`, `widgets/ui/*`, `widgets/layout/*`, `widgets/guards/admin_route_guard.dart` | Provider ownership, persistence, backend-specific policy logic. |
| `lib/providers` | Riverpod state ownership, derived selectors, and controller/mutation coordination. | `app_core_providers.dart`, `app_services.dart`, `cafe_controller.dart`, `profile_controller.dart`, `offline_sync_notifier.dart`, `app_selectors.dart`, `district_providers.dart` | SQL, raw HTTP request construction, long-lived cache formats, model parsing. |
| `lib/repositories` | App-level data orchestration, source merging, cache coordination, in-flight request collapse. | `CafeRepository`, `CafeMergePolicy`, `DistrictRepository`, `ProfileRepository`, `FriendRepository` | Widget state, UI copy, direct rendering behavior. |
| `lib/services` | External and device integrations: Supabase, Google Places, local storage, connectivity, reviews, favorites, offline queue, images, analytics. | `PlacesService`, `CafeQueryService`, `CafeCommandService`, `ProfilesService`, `ReviewsService`, `FavoritesService`, `LocalStorageService`, `OfflineQueueService`, `ConnectivityService`, `AppImageCacheManager`, `FirebaseAnalyticsService`, `DebugAnalyticsService` | Riverpod UI state, screen-specific filtering, broad product flow decisions. |
| `lib/models` | Data structures and parsing from Supabase/Google/local cache. | `Cafe`, `CafeReview`, `CurrentUser`, `UserProfile`, `Filters`, `ServiceResult`, `AsyncResult`, `CafeCacheMetadata` | Network calls, persistence side effects, provider reads. |
| `lib/utils` | Pure or near-pure helpers for classification, filtering, cache policy, logging, retry, cancellation, rate limiting, validation, text normalization. | `cafe_discovery_classifier.dart`, `filter_sort.dart`, `cafe_cache_policy.dart`, `rate_limiter.dart`, `inflight_request_registry.dart`, `retry.dart`, `request_cancellation.dart`, `service_error.dart`, `review_moderation.dart`, `log_redaction.dart` | Stateful app orchestration, UI widget code, Supabase client calls. |
| `lib/navigation` | GoRouter setup and route guard logic. | `app_router.dart`, `appRouteGuardRedirect()`, `GoRouterNotifier` | Backend authorization assumptions; route guards are not security boundaries. |
| `lib/l10n` | Generated and ARB localization files. | `app_en.arb`, `app_tr.arb`, generated localization classes | Business rules, hard-coded service errors outside localized mappings. |
| `supabase` | Database schema, RLS policies, readiness function, review cooldown trigger, security audit docs. | `cafe_optimizations_schema.sql`, `cafe_reviews*.sql`, `cafe_reviews_rate_limit.sql`, `cafe_soft_delete_and_favorite_count.sql`, `districts.sql`, `security_readiness_function.sql`, `SECURITY_READINESS.md` | Client-only UX behavior, Flutter provider state. |

## 4. Runtime Data Flow

General read flow:

```text
Screen -> Riverpod provider/controller -> repository -> service -> Supabase/Google Places
       -> repository cache/merge -> provider state/selectors -> UI
```

General mutation flow:

```text
Screen action -> controller/notifier -> service -> Supabase
             -> cache invalidation / provider invalidation -> refreshed provider state -> UI
```

### Home / Explore cafe list

Current implementation:

1. `HomeScreen` and `ExploreScreen` depend on selectors exported from `lib/providers/cafe_providers.dart`, especially `featuredCafesProvider`, `exploreCafeResultsProvider`, `filteredCafesProvider`, `cafesProvider`, and cache/error selectors.
2. `CafeNotifier.ensureVisibleCafeDataLoaded()` lazily starts discovery when a screen needs cafe data.
3. `CafeNotifier.loadCafes()` builds a discovery request using filters, radius, current/fallback coordinates, and `CafeCacheKeys`.
4. `CafeRepository.fetchCafes()` loads from memory/Hive cache when valid, deduplicates concurrent requests, applies repository rate limiting, and calls `PlacesService.fetchCafes()` when remote data is needed.
5. `PlacesService` calls Google Places search endpoints and returns `PlacesResult`.
6. `CafeRepository._mergeGoogleAndSupabase()` fetches Supabase overlays through `CafeQueryService`, filters blocked/deleted rows, applies `CafeMergePolicy`, and writes cache snapshots.
7. `CafeState` is updated with cafes, pagination, warnings, stale-cache status, diagnostics, and sync state.
8. `app_selectors.dart` derives Explore-specific filtering and sorting without mutating the shared cafe list.

### Map discovery

Current implementation:

1. `MapScreen` reads `mapVisibleCafesProvider`, `mapFilteredCafesProvider`, `mapCafeResultsProvider`, `mapRadiusPresetProvider`, selected cafe selectors, and loading/error selectors.
2. `CafeNotifier` owns `mapRadiusPreset`, `displayedMapRadiusPreset`, `mapFilters`, selected cafe ID, and focus version.
3. Map radius changes call `CafeNotifier.setMapRadiusPreset()`, persist discovery preferences, and can force a remote refresh.
4. Map filters are independent from Explore filters through `CafeState.mapFilters`.
5. Map view position is persisted through `CafeNotifier.persistMapView()` and `LocalStorageService.saveMapViewCache()`.
6. Stale requests are cancelled by `RequestCancellationController` and guarded by `_cafesRequestVersion`.

### Cafe detail

Current implementation:

1. `CafeDetailScreen` is routed through `/cafe/:id` in `app_router.dart`.
2. Detail UI reads `cafeByIdProvider`, detail loading/error selectors, review providers, favorite/compare selectors, and `cafeReviewSummaryProvider`.
3. `CafeNotifier.loadCafeDetail()` first uses an already loaded cafe if it has enough detail data.
4. `CafeRepository.fetchCafeDetails()` checks cached detail, loads Supabase detail through `CafeQueryService`, optionally fetches Google details through `PlacesService.fetchCafeDetails()`, merges sources with `CafeMergePolicy.mergeCafeSources()`, and saves detail cache.
5. `paginatedCafeReviewsProvider(cafeId)` loads reviews through `ReviewsService.fetchReviews()`.

### Favorites

Current implementation:

1. Favorite UI reads `favoritesProvider`, `orderedFavoriteIdsProvider`, `favoriteIdsProvider`, `favoriteCafesProvider`, `resolvedFavoriteCafesProvider`, `isCafeFavoritedProvider`, pending/error selectors, and `ProfileState`.
2. `ProfileNotifier.handleSessionChanged()` loads Hive favorites and Supabase favorites concurrently.
3. Supabase favorites are treated as source of truth when available; Hive is fallback cache.
4. `ProfileNotifier.toggleFavorite()` applies optimistic local state, writes Hive through `LocalStorageService`, and syncs through `FavoritesSyncGateway` / `FavoritesService`.
5. On sync failure, the notifier rolls back/marks failed state; tests cover optimistic update and retry behavior.

Not confirmed in current repo:

- Offline favorite toggles are not enqueued for later remote replay. `OfflineQueueService` explicitly drains legacy favorite queue entries without retrying remote sync.

### Compare

Current implementation:

1. Compare UI reads `compareListProvider`, `normalizedCompareListProvider`, `comparedCafeIdsProvider`, `isCafeInCompareListProvider`, `isCompareListFullProvider`, `comparedCafesProvider`, `resolvedComparedCafesProvider`, and `comparedResolvedCafesProvider`.
2. `ProfileNotifier` owns compare IDs in `ProfileState.compareList`.
3. Compare state is scoped by current user or guest and persisted through `LocalStorageService.saveCompareList()`.
4. Compare list is normalized, deduplicated, capped at four cafes, and resolved against current cafes and repository lookups.

### Reviews

Current implementation:

1. Detail/review widgets read `paginatedCafeReviewsProvider(cafeId)`, `currentUserCafeReviewProvider(cafeId)`, `reviewSubmissionControllerProvider(cafeId)`, and `reviewDeletionControllerProvider(cafeId)`.
2. `ReviewSubmissionController.submitReview()` blocks duplicate in-flight submits, checks connectivity, queues offline submissions when offline or transient failure occurs, and calls `ReviewsService.submitReview()`.
3. `ReviewsService.submitReview()` validates user/rating/content, moderates content, checks duplicate text, applies a local per-user 30-second cooldown, inserts or updates `cafe_reviews`, and maps errors to typed failures.
4. `supabase/cafe_reviews_rate_limit.sql` enforces a backend 30-second mutation cooldown for direct API callers.
5. Offline replay bypasses the local submission cooldown but still depends on backend acceptance.

### Admin add/edit/delete/restore

Current implementation:

1. Admin routes are guarded by `appRouteGuardRedirect()` and admin UI guard widgets.
2. Admin list/detail state is owned by `adminCafeListControllerProvider`, `adminCafesProvider`, and `adminCafeDetailsProvider`.
3. Mutations are coordinated by `cafeAdminMutationControllerProvider` and pending IDs in `adminCafeMutationPendingIdsProvider`.
4. Before admin mutations, `CafeAdminMutationController._ensureSecurityReadinessForAdminMutation()` reads `securityReadinessProvider`; unhealthy readiness blocks destructive mutations.
5. `CafeCommandService` performs add, admin update, soft delete, and restore operations against Supabase.
6. After mutation, providers invalidate favorites/compare derived cafes, clear `CafeRepository` caches, refresh admin list, and refresh public cafe discovery state.
7. Supabase RLS policies are still the authoritative protection if a modified client bypasses the Flutter route guard.

## 5. Provider / State Ownership Map

| Provider name | Owned state | Reads from | Writes to | Important side effects | Screens depending on it |
| --- | --- | --- | --- | --- | --- |
| `appShellProvider` | `AppShellState`: startup status, theme mode, current user, auth readiness, onboarding, admin flag, sign-out flag. | Supabase auth session, `securityReadinessProvider`, `profileProvider`, `friendsProvider`, `analyticsServiceProvider`. | App shell state only. | Subscribes to auth changes, logs missing env config, starts startup preload, tracks `app_open`, runs security readiness check. | Router, Auth, Profile, Settings, admin route guard, app shell. |
| `cafeProvider` | `CafeState`: cafe list, location, filters, map radius, pagination, selected cafe, cache status, detail loading/errors. | `cafeRepositoryProvider`, `localStorageServiceProvider`, `connectivityServiceProvider`, `activeDistrictsProvider`, `analyticsServiceProvider`. | `CafeState`, local discovery preferences/map cache. | Startup cache hydration, lazy discovery, cancellation/versioning, refresh-on-connectivity-return, tracks cafe detail opens, search/filter use, and map radius changes. | Home, Explore, Map, Cafe Detail, Favorites fallback, Compare fallback. |
| `profileProvider` | `ProfileState`: favorites, pending/failed favorite IDs, compare list, preferences. | `currentUserProvider`, `localStorageServiceProvider`, `favoritesServiceProvider`, `favoritesSyncGatewayProvider`, `cafesProvider`, `analyticsServiceProvider`. | Hive favorites/compare/preferences, Supabase favorites via service. | Session-scoped local hydration, optimistic favorites, compare persistence, rollback on sync failure, tracks successful favorite/compare mutations. | Favorites, Compare, Cafe cards/detail, Profile, Settings. |
| `offlineSyncProvider` | `OfflineSyncState`: pending and dead-letter counts. | `offlineQueueServiceProvider`. | Offline queue via service. | Bridges `OfflineQueueService` listenables into provider state; exposes queue processing. | Profile/settings/offline status surfaces; review/profile mutation controllers. |
| `districtConfigProvider` | `DistrictConfigState`: districts, source, loading/refreshing, last update. | `districtRepositoryProvider`, `connectivityServiceProvider`, `discoveryCityProvider`. | District state and district cache through repository/storage. | Loads fallback/cache first, refreshes remote config, refreshes when connectivity returns. | Home, Explore, Map, filters, Places discovery request construction. |
| `paginatedCafeReviewsProvider(cafeId)` | `PaginatedCafeReviewsState`: current page of reviews, pagination, load errors. | `reviewsServiceProvider`. | Review state only. | Auto-refresh on creation, paginated loads. | Cafe Detail review section. |
| `reviewSubmissionControllerProvider(cafeId)` | Async submit state. | `connectivityServiceProvider`, `offlineSyncProvider`, `reviewsServiceProvider`, `paginatedCafeReviewsProvider`, `analyticsServiceProvider`. | Review service, offline queue, review provider refresh. | Duplicate submit guard, queues transient/offline failures, refreshes reviews on success, tracks `review_submitted` on accepted/queued submit. | Cafe review form. |
| `reviewDeletionControllerProvider(cafeId)` | Async delete state and pending review IDs. | `reviewsServiceProvider`, `paginatedCafeReviewsProvider`, `analyticsServiceProvider`. | Supabase review deletion through service. | Prevents duplicate delete taps, refreshes reviews on success, tracks `review_deleted`. | Cafe review list/detail. |
| `adminCafeListControllerProvider` | `AdminCafeListState`: admin cafes, search/district/status filters, pagination, errors. | `cafeQueryServiceProvider`. | Admin list state. | Loads admin pages, merges pages by canonical identity. | Admin screen. |
| `adminCafeDetailsProvider(cafeId)` | Future detail lookup for admin edit. | `cafeQueryServiceProvider`, admin list state, public cafe state. | None directly. | Falls back to loaded admin/public cafes if service unavailable or lookup fails. | Cafe edit screen. |
| `cafeAdminMutationControllerProvider` | Async admin mutation state. | `securityReadinessProvider`, `cafeCommandServiceProvider`, cafe/admin/favorite/compare providers, `analyticsServiceProvider`. | Supabase cafes through service, provider invalidation, repository cache clearing. | Blocks mutations when readiness fails; refreshes canonical state after mutation; tracks admin add/update/delete/restore after successful mutations. | Admin add/edit/delete/restore flows. |
| `adminCafeMutationPendingIdsProvider` | Set of cafe IDs with pending admin mutation. | Admin mutation controller. | Pending ID set. | Prevents duplicate destructive actions. | Admin screen buttons. |
| `securityReadinessProvider` | Future `SecurityReadinessReport`. | `securityReadinessServiceProvider`. | None directly. | Calls Supabase readiness function or returns not-configured report. | App startup, admin mutation gate. |
| `analyticsServiceProvider` | Analytics sink instance only. | `kReleaseMode`. | Firebase Analytics in release; debug app logs in dev/test. | Hashes cafe IDs, logs query length instead of raw search, logs filter categories only, and swallows analytics failures. | App shell, cafe, profile, review, and admin controllers. |
| `placesServiceProvider` | Service instance lifecycle only. | `activeDistrictsProvider`, `discoveryCityDisplayNameProvider`. | None directly. | Disposes `PlacesService`. | `CafeRepository`. |
| `cafeRepositoryProvider` | Repository instance with memory caches and in-flight registries. | `placesServiceProvider`, `cafeQueryServiceProvider`, `localStorageServiceProvider`, `connectivityServiceProvider`. | Memory/Hive cafe caches through repository methods. | Disposes repository/rate limiter; combines Google/Supabase. | `CafeNotifier`, admin mutation refresh. |
| `connectivityServiceProvider` / `connectivityProvider` | Connectivity service and online stream. | `connectivity_plus`. | Connectivity stream state. | Starts connectivity subscription; default online in unsupported/test hosts. | Cafe, district, offline, review/profile controllers. |
| `localeModeProvider` / `appLocaleProvider` | Locale mode and resolved locale. | `LocalStorageService` through locale notifier. | Local locale mode cache. | Persists locale preference. | `MaterialApp`, Settings. |
| `friendsProvider`, `friendRelationshipsProvider`, `friendLocationPresenceProvider` | Friend state and derived friend snapshots. | `friendRepositoryProvider`, `currentUserProvider`. | `FriendsState` only. | Uses `NoopFriendsService`; returns empty/unavailable data. | Social/friend placeholders only. |

Derived selectors in `lib/providers/app_selectors.dart` should stay pure. They should read provider state and compute views such as `filteredCafesProvider`, `mapVisibleCafesProvider`, `favoriteCafesProvider`, and `comparedCafesProvider`; they should not call remote services or mutate storage.

## 6. Repository & Service Responsibility Map

| Class/file | Responsibility | Upstream caller | Downstream dependency | Cache usage | Failure behavior |
| --- | --- | --- | --- | --- | --- |
| `CafeRepository` (`lib/repositories/cafe_repository.dart`) | Client-side cafe source orchestration, cache load/save, Google/Supabase merge, delete blocking, detail fallback, in-flight request dedupe. | `CafeNotifier`, admin mutation refresh, favorite/compare resolution. | `PlacesServiceBase`, `CafeOverlaySource` / `CafeQueryService`, `LocalStorageService`, `ConnectivityService`. | LRU list/detail/popular district caches plus Hive list/detail caches. | Returns `CafeRepositoryResult` with warning/error; uses cached data offline/throttled; maps service failures to user-facing messages. |
| `CafeMergePolicy` (`lib/repositories/cafe_merge_policy.dart`) | Field-level precedence between Google Places and Supabase, review overlay, deleted Google place suppression. | `CafeRepository`, tests. | `Cafe`, `CafeReview`, `GooglePlaceData`. | None. | Pure deterministic merge; skips deleted Supabase rows. |
| `DistrictRepository` (`lib/repositories/district_repository.dart`) | District config cache/refresh/fallback coordination. | `DistrictConfigNotifier`. | `DistrictsService`, `LocalStorageService`, fallback district catalog. | In-memory city cache and Hive district cache. | Falls back to cache or bundled districts when remote unavailable. |
| `ProfileRepository` (`lib/repositories/profile_repository.dart`) | Profile read wrapper. | `AppShellNotifier`. | `ProfilesService`. | None confirmed. | Returns null/failure through service result semantics. |
| `FriendRepository` (`lib/repositories/friend_repository.dart`) | Wrapper for future friend relationships/map presence. | Friend providers. | `FriendsServiceBase`. | None. | Current `NoopFriendsService` returns empty data/unavailable mutation failures. |
| `PlacesService` (`lib/services/places_service.dart`) | Google Places discovery, text/nearby search, details, candidate filtering, pagination, diagnostics. | `CafeRepository`. | `http.Client`, Google Places API, `Env.googlePlacesApiKey`. | LRU nearby/text/detail caches and in-flight registries. | Timeouts, retries, typed `AppServiceException`, 429 rate-limit mapping, malformed place skips. |
| `CafeQueryService` (`lib/services/supabase_service.dart`) | Supabase cafe reads for public discovery, overlays, admin list, detail, IDs/place IDs. | `CafeRepository`, admin providers. | `SupabaseClient`. | In-flight dedupe for place ID/detail style reads. | `ServiceResult` failures for timeout/auth/network/parse/service errors. |
| `CafeCommandService` (`lib/services/supabase_service.dart`) | Supabase admin cafe mutations: add, update, soft delete, restore. | `CafeAdminMutationController`. | `SupabaseClient`. | None directly; controller/repository clear caches after mutation. | Validates before writes where possible; maps conflicts/permission/timeouts. |
| `ReviewsService` (`lib/services/reviews_service.dart`) | Fetch, submit/update, delete reviews; moderation, duplicate text, local cooldown, error mapping. | Review providers/controllers, `OfflineQueueService`. | `SupabaseClient`. | In-flight page request map; local `_lastSubmissionTimeByUser`. | Returns `ServiceResult`; maps rate limit to review-specific error; validates unauthenticated/invalid inputs before remote writes. |
| `FavoritesService` (`lib/services/favorites_service.dart`) | Load/add/remove favorites in Supabase. | `ProfileNotifier` through `favoritesServiceProvider`/`FavoritesSyncGateway`. | `SupabaseClient`. | In-flight favorite load registry. | `loadFavorites()` returns null on failure so caller can fall back to Hive; add/remove return bool. |
| `ProfilesService` (`lib/services/supabase_service.dart`) | Profile fetch/update, role update, avatar upload/delete, admin user listing. | `AppShellNotifier`, profile update controller, admin users provider, offline queue. | `SupabaseClient`, Supabase Storage. | None confirmed. | Validates avatar extension/size/content; returns typed `ServiceResult`. |
| `LocalStorageService` (`lib/services/local_storage_service.dart`) | Encrypted Hive storage for favorites, compare, preferences, filters, discovery state, district cache, cafe list/detail cache, map view, offline queue/dead letters. | Main provider override, `CafeRepository`, `CafeNotifier`, `ProfileNotifier`, `OfflineQueueService`, `DistrictRepository`. | Hive, Flutter Secure Storage. | Persistent L2 cache. | Migrates plaintext to encrypted storage; recreates encrypted box if key lost; prunes stale/overflow caches. |
| `OfflineQueueService` (`lib/services/offline_queue.dart`) | Queue/replay offline review submissions and profile updates; dead-letter handling. | `OfflineSyncNotifier`, review/profile controllers. | `LocalStorageService`, `ConnectivityService`, `ReviewsService`, `ProfilesService`. | Hive offline queue/dead letters. | Dedupe by review user+cafe and profile user; rate-limited reviews stay queued; unrecoverable failures dead-letter. |
| `ConnectivityService` (`lib/services/connectivity_service.dart`) | Online/offline stream. | Cafe, district, offline, review/profile controllers. | `connectivity_plus`. | Current online flag in memory. | Defaults online when plugin missing. |
| `AppImageCacheManager` (`lib/services/app_image_cache_manager.dart`) | Remote image cache manager with timeout. | Remote image widgets/cache manager users. | `flutter_cache_manager`, `http`. | Cache key `kafeprojeImageCacheV3`, 10-day stale period, max 120 objects. | Image HTTP fetch timeout uses `NetworkTimeoutConfig.imageRequestTimeout`. |
| `FirebaseAnalyticsService` / `DebugAnalyticsService` (`lib/services/analytics_service.dart`) | Minimal production/dev analytics abstraction for release-readiness events. | `analyticsServiceProvider`, app/cafe/profile/review/admin controllers. | `FirebaseAnalytics` in release; `AppLogger` in dev/test. | None. | Fire-and-forget logging; analytics failures are caught and do not block user flows. Cafe IDs are hashed, search logs only query length, filters log category names only. |

## 7. Cafe Discovery, Merge, Classification, and Deletion Rules

This section is release-critical.

### Source combination

Current implementation:

- Google Places candidates are fetched by `PlacesService`.
- Supabase overlay rows are fetched by `CafeRepository._mergeGoogleAndSupabase()` through `CafeQueryService`.
- When district discovery is active, or Google returns empty, the repository also fetches a discoverable Supabase baseline.
- Supabase overlays are fetched by Google place IDs with `includeDeleted: true` so deleted/hidden rows can block returning Google candidates.
- `CafeMergePolicy.mergeGooglePlacesWithSupabase()` merges by `Cafe.canonicalIdentityKey`.
- `applySharedBrandPricing()` is applied after merge.

Field precedence in `CafeMergePolicy`:

- Google owns canonical live place metadata by default.
- Supabase owns app/community fields: app rating/review count, wifi, outlet, quietness, study/pet/outdoor, smoking policy, owner approval status, app-managed overrides.
- Supabase custom place overrides are used when `Cafe.usesAppManagedFields` is true.
- Live reviews can temporarily overlay rating/community fields with `CafeMergePolicy.applyReviewOverlay()`.

### What counts as a cafe

Current implementation in `lib/utils/cafe_discovery_classifier.dart`:

- Allowed Google place types include `cafe`, `coffee_shop`, `coffee_roastery`, `coffee_stand`, and `tea_house`.
- Positive text signals include cafe/kafe/coffee/kahve/espresso/roastery/third wave/specialty/brew.
- Known brands such as Starbucks, Mikel Coffee, Caffe Nero, Kahve Dunyasi, EspressoLab, Caribou, Tchibo, Costa Coffee, and Fig Coffee receive strong positive score.
- A candidate must have meaningful identity and enough score/positive signal unless it is explicitly admin-allowed.

### Strong cafe signals

Strong signals include:

- Primary or secondary Google type in allowed cafe place types.
- Strong cafe name tokens such as `cafe`, `kafe`, `coffee`, `kahve`, `espresso`.
- Whitelisted cafe brands.
- Multiple positive cafe keywords.

### Weak/mixed venue signals

Mixed signals are handled carefully:

- Bar/pub/bistro/cocktail-style tokens are weak mixed venue signals.
- A mixed venue can pass only when explicit cafe signals are also present and negative dominance does not win.
- `Fig Coffee & Cocktail` is explicitly covered by brand/test data and the cafe soft-delete migration keeps its canonical Supabase row approved.

### Hard deny terms and strong negatives

Hard-blocked phrase patterns include:

- `borek ve pide`, `borek ve pide salonu`, `pide salonu`, `lahmacun salonu`, `yemek salonu`, `unlu mamul`, `unlu mamulleri`.
- Gaming/internet phrases such as `internet cafe`, `internet kafe`, `playstation cafe`, `gaming cafe`, `computer cafe`, `oyun cafe`, `oyun salonu`, `ps cafe`, `game center`, `atari salonu`.

Strong negative tokens include food-only, market, gaming, and traditional non-cafe venue tokens such as borek, pide, kebap, doner, lahmacun, pizza, firin, simit, kiraathane, kahvehane, internet, esports, playstation, gaming, xbox, konsol, bilardo, market, bakkal, grocery, supermarket, and tekel.

Important rule: deny-first hard blocks override cafe-like names, whitelisted-brand-like wording, and Google cafe/coffee_shop typing.

### Gaming/internet/playstation cafe rejection

Current implementation:

- `internet_cafe` is in denied primary Google types.
- Gaming/internet tokens and phrase patterns are in hard/strong negative lists.
- Tests in `test/cafe_discovery_classifier_test.dart` verify that internet and gaming cafes are rejected even when the word cafe is present.

### Nargile/shisha-only handling

Current implementation:

- `nargile`, `nargileci`, `hookah`, and `shisha` are treated as nargile-only tokens.
- If those tokens appear without explicit strong cafe signal, the candidate is rejected with deny reason `nargile_without_cafe_signal`.
- A cafe with both shisha/nargile and real cafe signals can still be evaluated by the scoring path instead of being automatically rejected.

### Admin-approved Supabase rows

Current implementation:

- `isStrictlyValidCafe()` rejects blocked rows first.
- Admin allow tags can override classifier rejection only after the cafe passes public blocking checks.
- Admin allow tags include `admin_allow_cafe`, `force_cafe`, and `manual_verified_cafe` variants.
- Tests in `test/cafe_repository_test.dart` cover explicit admin cafe override tags and confirm they do not bypass hidden/deleted status.

### Soft-deleted cafes and Google reappearance prevention

Current implementation:

- `Cafe.isDeleted`, non-approved `ownerApprovalStatus`, hidden/inactive/deleted row fields, and `deleted_at` suppress public display.
- `CafeRepository._buildBlockedIdentifierSet()` builds block identifiers from deleted/hidden/non-approved Supabase overlays.
- Google candidates are removed when they match a blocked Supabase row by:
  - Google place ID.
  - Canonical identity key.
  - Fallback key of normalized name plus coordinates rounded to four decimals.
- `CafeMergePolicy.mergeGooglePlacesWithSupabase()` also skips Google rows whose place ID is in deleted Supabase rows.
- Tests in `test/cafe_merge_policy_test.dart` and `test/cafe_repository_test.dart` cover Google candidates being dropped when matching Supabase rows are soft-deleted.

### Duplicate detection and merging

Current implementation:

- `Cafe.canonicalIdentityKey` is the merge identity used by repository and merge policy.
- Model tests cover `dedupKey` preferring stable place ID over display-name similarity.
- Admin list pagination merges pages by canonical identity to avoid duplicate admin rows in list state.
- Compare list normalization dedupes IDs and caps at four.
- Local cache replacement updates only matching cached list entries.

### Stale cache protection

Current implementation:

- `CafeCachePolicy` defines list fresh/hard TTL and detail fresh/hard TTL.
- Stale list entries can be shown while refresh is in progress; expired entries are evicted and not shown.
- `CafeNotifier` request versions and cancellation tokens prevent older discovery/detail responses from overwriting newer state.
- `LocalStorageService._mergeCafeForCache()` preserves richer image data during cache replacement.
- Tests cover stale cache startup behavior, older discovery responses not overwriting newer filter results, superseded detail responses, and cache metadata handling.

Key tests:

- `test/cafe_discovery_classifier_test.dart`
- `test/places_service_test.dart`
- `test/cafe_merge_policy_test.dart`
- `test/cafe_repository_test.dart`
- `test/model_parsing_test.dart`
- `test/cafe_cache_test.dart`
- `test/app_provider_startup_test.dart`
- `test/local_storage_service_test.dart`

## 8. Caching, Rate Limiting, and Request Deduplication

### Memory caches

Current implementation:

- `CafeRepository`:
  - List cache: `LruCache<String, CafeListCacheSnapshot>`, max 8, TTL 6 minutes.
  - Detail cache: `LruCache<String, Cafe>`, max 96, TTL 6 hours.
  - Popular district count cache: max 12, TTL 10 minutes.
- `PlacesService`:
  - Text search cache: max 24, TTL 8 minutes.
  - Place details cache: max 96, TTL 6 hours.
  - Nearby/query memory settings use `RequestTuningConfig`.
- `LruCache` evicts expired entries on access and removes least-recently-used entries over size.

### Local persisted caches

Current implementation in `LocalStorageService`:

- Encrypted Hive box `app_state`.
- Favorites: `favorites:{scope}`.
- Compare: `compare:{scope}`.
- Preferences: `preferences:{scope}`.
- Filter presets: `filter_presets:v1:{scope}`.
- Cafe discovery preferences: `cafes:discovery:v1`.
- District config: `districts:config:v1:{city}`.
- Cafe lists: `cafes:list:v4:{cacheKey}`.
- Cafe details: `cafes:detail:v3:{cafeId}`.
- Map view: `map:view:v1`, max age 7 days.
- Offline queue/dead letters: `offline:queue:v1`, `offline:dead:v1`.

Cache policy:

- Cafe list fresh TTL: 30 minutes.
- Cafe list hard TTL: 24 hours.
- Cafe detail memory fresh TTL: 6 hours.
- Cafe detail hard TTL: 24 hours.
- Persistent list entry limit: 12.
- Persistent detail entry limit: 36.
- District fresh TTL: 12 hours.
- Photo metadata fresh TTL: 10 days.

### Image cache behavior

Current implementation:

- Flutter global image cache is capped by `ImageCacheConfig`: 120 entries and 60 MB.
- `AppImageCacheManager` uses cache key `kafeprojeImageCacheV3`, stale period 10 days, max 120 objects, and a 10-second image request timeout.

### Google Places endpoint bucket limits

Current implementation in `RequestTuningConfig` and `PlacesService`:

| Bucket | Minimum interval |
| --- | --- |
| `nearby_search` | 650 ms |
| `text_search` | 400 ms |
| `place_details` | 300 ms |
| `photo_fetch` | 300 ms |
| `reverse_geocode` | 500 ms |

Other Google request settings:

- Max request attempts: 3.
- Nearby max result count: 20.
- Text search page size: 20.
- Max text search pages: 8.
- Places request timeout: 10 seconds.
- Pagination delay: 2 seconds.
- Retry initial delay: 350 ms.
- Retry backoff multiplier: 1.8.

### Repository throttling

Current implementation:

- `CafeRepository` has its own `RateLimiter` for `nearby_search` and `place_details`.
- If a repeated request is throttled and a cached snapshot exists, repository returns cached data with warning `"Using recently cached cafes."`.
- Internal refreshes can bypass the limiter when explicitly requested; covered by `test/cafe_repository_test.dart`.

### In-flight request deduplication

Current implementation:

- `InflightRequestRegistry<T>` returns the same `Future<T>` for the same key until completion.
- Used by `CafeRepository` for cafe list, cafe details, and popular district counts.
- Used by `PlacesService` for cafe searches, text pages, and raw details.
- Used by `FavoritesService` and `ReviewsService` for load/page requests.

### Debounce rules

Configured values:

- Map fetch debounce: 600 ms.
- Filter change debounce: 300 ms.
- Search input debounce: 350 ms.

Current repo note:

- These values exist in config and are used by UI/provider flows where wired. Verify each new UI search/filter control uses the shared config rather than local ad hoc durations.

### Cancellation/versioning

Current implementation:

- `CafeNotifier` keeps `_cafesRequestVersion` and `_detailRequestVersions`.
- New cafe list requests cancel older list and load-more requests.
- New detail requests cancel older detail requests for the same cafe.
- Cancelled service calls classify as `ServiceErrorType.cancelled` and do not surface user errors.

### Offline/throttled fallback

Current implementation:

- Offline cafe list request with cache: returns cached cafes with offline warning.
- Offline cafe list request without cache: returns an offline/no-cache error.
- Throttled cafe list with cache: returns cached cafes.
- Detail request while offline: returns cached detail/fallback if available.
- Review submit offline/transient failure: queues for replay.
- Profile update offline/transient failure: queues for replay.

## 9. Offline and Resilience Model

What still works offline:

- Previously cached cafe lists and details.
- Persisted map view.
- Persisted favorites and compare lists.
- Persisted preferences/filter presets/locale.
- District fallback/cache.
- Offline review submission queueing.
- Offline profile update queueing.

What falls back to cache:

- Cafe list discovery through `CafeRepository`.
- Cafe details through repository cached detail or loaded list fallback.
- Favorites through Hive when Supabase favorite load fails.
- District config through Hive or bundled fallback catalog.

What is queued for later:

- Review submissions through `OfflineQueueService.enqueueReviewSubmission()`.
- Profile updates through `OfflineQueueService.enqueueProfileUpdate()`.

What fails fast:

- Unauthenticated review submission.
- Invalid review rating/content.
- Missing required admin cafe name.
- Unsupported/oversized/malformed avatar upload.
- Admin mutations when security readiness blocks them.
- Service unavailable when required Supabase service provider is null.

Timeout/retry/backoff:

- Auth timeout: 12 seconds.
- Supabase data timeout: 15 seconds.
- Review timeout: 15 seconds.
- Upload timeout: 2 minutes.
- Google Places timeout: 10 seconds.
- Image timeout: 10 seconds.
- Google Places retries 429 and 5xx through `retryAsync()` with 3 attempts, 350 ms initial delay, 1.8x backoff.

Typed error handling:

- `ServiceErrorType` covers auth, cancelled, network, rateLimit, timeout, validation, conflict, notFound, parse, unavailable, and unknown.
- `classifyServiceError()` maps messages/exceptions into typed categories.
- `AppErrorCode` is mapped to localized UI messages through `localized_error.dart`.
- Review/favorite/admin controllers keep previous data where possible and surface typed errors rather than raw exceptions.

## 10. Security Model

### Client-side UX Security

Current implementation:

- `app_router.dart` redirects unauthenticated users to `/auth` and non-admin users away from `/admin`, `/cafe-add`, and `/cafe-edit/:id`.
- `GoRouterNotifier` refreshes routing only on auth/admin/onboarding state changes.
- Admin UI guard exists under `lib/widgets/guards/admin_route_guard.dart`.
- Input validation is implemented in `input_validation.dart`, review validation/moderation in `ReviewsService` and `review_moderation.dart`, and avatar validation in `ProfilesService`.
- `log_redaction.dart`, safe Places HTTP failure logging, and `AppLogger` reduce sensitive log exposure.

Limit:

- Client-side checks can be bypassed by a modified app or direct HTTP calls. They are not authoritative security controls.

### Backend Authoritative Security

Current implementation:

- `cafe_optimizations_schema.sql` enables RLS on `cafes` and creates public SELECT plus admin-only INSERT/UPDATE policies.
- `cafe_reviews.sql` enables RLS on `cafe_reviews`, allows public SELECT, and restricts INSERT/UPDATE/DELETE to own review rows.
- `cafe_reviews_v4.sql` enforces one review per user per cafe through a unique index.
- `cafe_reviews_rate_limit.sql` enforces authenticated review ownership and a 30-second mutation cooldown in Postgres.
- `cafe_soft_delete_and_favorite_count.sql` adds `is_deleted`, `deleted_at`, `deleted_by`, and `favorite_count`.
- `security_readiness_function.sql` defines `public.app_security_readiness()` to verify critical cafes RLS/policy setup.

### Threat Model

| Attack scenario | Protection layer | Current mitigation | Remaining risk | Release blocker? |
| --- | --- | --- | --- | --- |
| Modified client bypasses route guard | Supabase RLS | Admin insert/update require admin profile role/is_admin policy. Review mutations require ownership. | Delete policy for cafes is not present; app uses soft delete via update. Direct table permissions must stay aligned with RLS. | Yes if RLS audit fails. |
| Non-admin attempts cafe mutation | RLS + readiness gate | `Admins can insert cafes` and `Admins can update cafes` policies; app checks `app_security_readiness()` before admin mutations. | Readiness function only checks cafes RLS/admin insert/update policy presence, not every table/policy. | Yes. |
| User edits another user's review | RLS + trigger | `cafe_reviews` own-row policies; trigger rejects ownership mismatch/transfer. | Admin review deletion behavior depends on policies not visible in current SQL; current review table policy only allows own delete. | Yes if direct test succeeds. |
| Spam review mutations | Client cooldown + backend trigger | Local 30-second cooldown plus `cafe_review_rate_limits` trigger. | Cooldown is per user, not IP/device/global. Auth spam still depends on Supabase Auth/provider limits. | Yes if direct API bypass succeeds. |
| Deleted cafe returns from Google Places | Repository/merge deletion blocks | Deleted/hidden/non-approved overlays block Google candidates by place ID, canonical identity, and fallback name+coords. | If Google returns same venue with changed name and shifted coordinates and no place ID match, fallback may miss it. | Yes if known deleted cafe reappears. |
| Google API key extraction from client | Google Cloud restrictions | Keys loaded from `.env`/dart-define; app must rely on platform/API restrictions and quotas. | Client-side key cannot be kept secret. No backend proxy exists. | Yes if unrestricted keys are used for release. |
| Excessive Google API usage | Client throttles + Google quotas | Endpoint buckets, in-flight dedupe, cache, pagination limits, provider quota recommendation. | Modified client can bypass app throttles using extracted key unless Google restrictions/quotas are configured. | Yes if quotas/restrictions missing. |
| Stale cache poisoning UI | Cache policy + versioning | Hard TTL, request cancellation/versioning, cache metadata, stale-while-refresh UI state, richer data preservation. | Cache can still be stale within TTL; manual invalidation depends on admin mutation refresh path. | No unless critical flow shows wrong/deleted data. |

## 11. Supabase Schema & Migration Readiness

Required migration order:

| Order | Migration | Purpose | Tables/functions/policies affected | Release risk if missing |
| --- | --- | --- | --- | --- |
| 1 | Existing Supabase base schema, including `profiles` | Required dependency for profile FK and admin policy lookup. | `profiles` table. | App auth/profile/admin checks break. Not fully defined in current repo. |
| 2 | `supabase/cafe_soft_delete_and_favorite_count.sql` | Ensures `cafes` exists and adds soft delete/favorite fields plus canonical Fig row. | `cafes`, indexes. | Admin delete/restore and Google reappearance blocking lose backend fields. |
| 3 | `supabase/cafe_optimizations_schema.sql` | Enables RLS and creates public read/admin insert/admin update policies for cafes. | `cafes` RLS and policies. | Non-admin direct cafe mutation may be possible or app readiness fails. |
| 4 | `supabase/cafe_reviews.sql` | Creates `cafe_reviews`, RLS, own-row review policies, cafe/user indexes. | `cafe_reviews`. | Reviews do not work or are insecure. |
| 5 | `supabase/cafe_reviews_v2.sql` | Adds community review fields and defaults. | `cafe_reviews` columns/checks. | Review form fields fail or store incomplete data. |
| 6 | `supabase/cafe_reviews_v3.sql` | Makes review content optional. | `cafe_reviews.content`. | Rating-only reviews may fail. |
| 7 | `supabase/cafe_reviews_v4.sql` | Aligns smoking policy values and enforces one review per user per cafe. | `cafe_reviews` check/unique index. | Duplicate reviews and value mismatch risk. |
| 8 | `supabase/cafe_reviews_rate_limit.sql` | Enforces backend review mutation cooldown and ownership checks. | `cafe_review_rate_limits`, trigger/function on `cafe_reviews`. | Direct API review spam can bypass client cooldown. |
| 9 | `supabase/districts.sql` | Adds remote district config table and update trigger. | `districts`. | App falls back to bundled districts; remote district config unavailable. |
| 10 | `supabase/security_readiness_function.sql` | Adds runtime readiness probe. | `public.app_security_readiness()`. | Startup/admin readiness gate cannot verify critical RLS. |

Run readiness check:

```sql
SELECT public.app_security_readiness();
```

Pass result:

- JSON field `is_ready` is `true`.
- `rls_enabled`, `has_admin_insert_policy`, and `has_admin_update_policy` are true.
- Message says security readiness passed.

Fail result:

- `is_ready` is false or query errors.
- Admin mutations must be blocked until migration/policy state is fixed.

Direct Supabase malicious-client audit scenarios:

- Non-admin direct `INSERT` on `cafes` must fail.
- Non-admin direct `UPDATE` on `cafes` must fail.
- Non-admin direct soft-delete update (`is_deleted=true`) must fail.
- Anonymous direct cafe insert/update must fail.
- Expired JWT update must fail.
- Authenticated user direct review insert for another `user_id` must fail.
- Authenticated user direct review update/delete for another user's review must fail.
- Same user direct review mutations within 30 seconds must fail.
- Public cafe/review `SELECT` should succeed by design.

`supabase/SECURITY_READINESS.md` contains concrete malicious-client audit guidance for cafes RLS.

## 12. Google Places / API Key Operations

Current Google Places APIs used:

- `places:searchNearby` for nearby cafe/coffee-shop searches.
- `places:searchText` for text search and chain/city coverage.
- `places/{placeId}` for place details.
- Photo metadata is requested through `photos.name` field masks and converted into app image URLs/helpers.

Where calls are made:

- `lib/services/places_service.dart`
- API key source: `Env.googlePlacesApiKey` from `.env` or `--dart-define=GOOGLE_PLACES_API_KEY=...`.
- Maps key source: `Env.googleMapsApiKey`.

Required key restrictions:

- Restrict Android key by package name and SHA certificate.
- Restrict iOS key by bundle ID.
- Restrict web key by allowed HTTP referrers if web release is used.
- Restrict API scope to only required Maps/Places APIs.
- Do not ship placeholder keys.

Quota ceilings and alerts:

- Configure daily quota ceilings for Places API usage.
- Configure alerting for quota spikes and billing thresholds.
- Track searchNearby/searchText/details separately if Google Cloud metrics allow it.

Cost-control limitation:

- Client-side throttling reduces normal app spend but does not stop a modified client or extracted key from making direct requests.
- Provider-side restrictions/quotas are mandatory for release.

When an Edge Function/proxy becomes necessary:

- Google API cost becomes material or unpredictable.
- Abuse is detected despite key restrictions.
- Per-user/IP quotas are needed.
- Centralized request logging or policy enforcement is required.
- API key secrecy becomes a hard requirement.

## 13. Release Readiness Gates

Go/no-go checklist:

| Gate | Required result | Block release if failing |
| --- | --- | --- |
| `flutter analyze` | No issues. | Yes |
| Core tests | Relevant unit/widget tests pass. | Yes |
| Supabase migrations | All required migrations applied to target project. | Yes |
| `app_security_readiness()` | `is_ready = true`. | Yes |
| RLS malicious-client audit | Non-admin/anon/expired direct mutations fail; intended public reads pass. | Yes |
| Google API keys | Platform/API restricted, quotas and alerts configured. | Yes |
| Analytics privacy | Release build can send the configured minimal Firebase Analytics events; no email, display name, review text, raw search text, exact coordinates, or full addresses are logged. | Yes |
| Deleted cafe reappearance | Known soft-deleted cafes do not reappear from Google. | Yes |
| Review cooldown direct bypass | Direct Supabase repeated review mutation within 30 seconds fails. | Yes |
| Admin mutation by non-admin | Direct non-admin cafe insert/update/soft-delete fails. | Yes |
| Critical smoke flows | All pass on release build. | Yes |

Smoke test flows:

- Auth: sign up/sign in/sign out, auth rate-limit copy, redirect `from` handling.
- Home/Explore: startup cache hydration, lazy discovery, filters, search, empty/error states.
- Map: map view restore, radius changes, marker select, map filters, stale request cancellation.
- Cafe detail: correct cafe opens, details merge, image loading, review summary.
- Favorites: optimistic toggle, persistence, remote sync, retry/failure state.
- Compare: add/remove/cap at four, persistence, detail-to-compare path.
- Reviews: submit/update/delete, duplicate text, offline queue, cooldown, direct backend cooldown test.
- Profile/settings: profile update, avatar validation/upload, locale/theme preferences.
- Admin add/edit/delete/restore: readiness gate, pending button lock, public list refresh, deleted cafe suppression.
- Analytics: app open/detail/favorite/compare/review/map/search/filter/admin events are emitted without personal data.
- Offline/cache fallback: cached startup, offline list/detail, queued review/profile update, reconnect processing.

Useful test command:

```sh
flutter analyze
flutter test
```

Focused release-risk tests:

```sh
flutter test test/app_provider_startup_test.dart test/cafe_repository_test.dart test/cafe_merge_policy_test.dart test/cafe_discovery_classifier_test.dart test/places_service_test.dart
flutter test test/reviews_service_test.dart test/offline_queue_service_test.dart test/favorite_ux_test.dart test/compare_flow_test.dart test/navigation/app_router_test.dart
flutter test test/supabase_service_test.dart test/local_storage_service_test.dart test/rate_limiter_test.dart test/analytics_service_test.dart
```

## 14. Known Risks and Tradeoffs

| Risk/tradeoff | Current implementation | Impact | Mitigation |
| --- | --- | --- | --- |
| Client-side Google Places key exposure | Google Places calls are made directly from Flutter. | Key can be extracted from app builds. | Platform/API key restrictions, quotas, alerts; future proxy if needed. |
| Provider quotas instead of backend proxy | No Supabase Edge Function/backend proxy exists. | Per-user/IP rate limiting for Google is not authoritative. | Keep client throttles and caches; move to proxy when spend/abuse requires it. |
| Merge/classification complexity | Rules are split across `PlacesService`, `cafe_discovery_classifier.dart`, `CafeRepository`, and `CafeMergePolicy`. | Regression risk when changing venue rules. | Keep focused classifier/merge tests mandatory. |
| Offline cache staleness | Cache can be shown while stale but not expired. | UI may temporarily show old data. | Stale indicators, refresh-on-connectivity, hard TTL, mutation cache invalidation. |
| Admin workflow depends on RLS correctness | UI route guards are not enough. | Misconfigured Supabase project can expose mutations. | `app_security_readiness()`, malicious-client audit, release block on failure. |
| Minimal analytics only | Firebase Analytics now records release-readiness events, but there is no broader product funnel, alerting, or centralized operational dashboard in this repo. | Debugging production behavior still depends on Crashlytics, Google/Supabase consoles, and manual checks. | Keep analytics privacy tests and add observability only when operational need is clear. |
| Mobile-first runtime | Flutter targets exist for several platforms, but runtime behavior is mobile-oriented. | Web/desktop may expose unsupported flows or key restriction differences. | Treat non-mobile release as separate readiness effort. |
| Friends/social placeholder | `NoopFriendsService` returns empty/unavailable behavior. | UI depending on real social data would be misleading. | Keep social surfaces hidden/limited until backend exists. |
| Backend review cooldown granularity | Cooldown is per authenticated user. | Does not stop multi-account/IP-level abuse. | Add server-side per-IP/device quota if abuse appears. |

## 15. Future Architecture Options

| Option | Why it helps | When necessary | Cost/complexity | Priority |
| --- | --- | --- | --- | --- |
| Supabase Edge Function/backend proxy for Google Places | Hides Google key, centralizes quotas, logging, request normalization, and per-user/IP controls. | API spend/abuse becomes material, or key secrecy is required. | Medium/high: proxy endpoints, auth, caching, deployment, observability. | High after release if usage grows. |
| Stronger server-side per-user quota | Adds authoritative limits for reviews/admin/user actions beyond simple cooldowns. | Spam continues through many accounts or sensitive mutations expand. | Medium: SQL quota tables/functions or Edge middleware. | Medium. |
| Centralized observability | Builds on minimal Firebase Analytics with dashboards, release health metrics, API spend views, and privacy review. | Crashlytics plus minimal events are insufficient for production operations. | Medium: dashboard design, event taxonomy, privacy review, operational runbooks. | Medium. |
| Automated release smoke tests | Reduces manual release risk for auth/discovery/admin/cache flows. | Release cadence increases or regressions recur. | Medium/high: test env, seeded Supabase data, emulator/device automation. | High, but not implemented for current release. |
| Richer admin moderation workflow | Supports review/cafe moderation, audit trails, admin review deletion, abuse response. | User-generated content volume increases. | Medium: schema, RLS, UI, audit tests. | Medium. |
| Better cache invalidation/versioning | Reduces stale UI after admin edits and schema changes. | Cache staleness causes user-visible wrong data. | Medium: cache version protocol, server timestamps, invalidation events. | Medium. |

## 16. Appendix

### Important commands

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/cafe_discovery_classifier_test.dart
flutter test test/cafe_merge_policy_test.dart test/cafe_repository_test.dart
flutter test test/app_provider_startup_test.dart
flutter build apk --release
```

Supabase readiness:

```sql
SELECT public.app_security_readiness();
```

Environment keys:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
GOOGLE_MAPS_API_KEY
GOOGLE_PLACES_API_KEY
```

### Important test files

| Test file | Covers |
| --- | --- |
| `test/navigation/app_router_test.dart` | Auth/admin route guard redirects and safe `from` paths. |
| `test/app_provider_startup_test.dart` | Startup cache hydration, lazy discovery, stale cache refresh, request versioning, detail cancellation. |
| `test/cafe_cache_test.dart` | Cafe cache behavior, stale cache, remote failure fallback. |
| `test/cafe_discovery_classifier_test.dart` | Cafe classifier positive/negative/hard-block rules. |
| `test/places_service_test.dart` | Google candidate filtering and safe failure logs. |
| `test/cafe_merge_policy_test.dart` | Google/Supabase merge precedence and soft-delete blocking. |
| `test/cafe_repository_test.dart` | In-flight dedupe, fallback detail, timeout/cancel mapping, rate limiter bypass, Supabase overlay filtering. |
| `test/favorite_ux_test.dart` | Optimistic favorite flow, rollback, retry. |
| `test/compare_flow_test.dart` | Compare/favorite selector isolation. |
| `test/offline_queue_service_test.dart` | Offline queue dedupe/replay/dead-letter behavior. |
| `test/reviews_service_test.dart` | Review load dedupe, timeout mapping, validation. |
| `test/supabase_service_test.dart` | Cafe query/command/profile service behavior. |
| `test/local_storage_service_test.dart` | Encrypted Hive migration, cache isolation, filter preset persistence. |
| `test/rate_limiter_test.dart` | Rate limiter acquire/release/reset behavior. |
| `test/filter_sort_test.dart` | Filtering/sorting semantics and community-vs-Google rating behavior. |
| `test/model_parsing_test.dart` | Cafe parsing, Google metadata, dedup keys, district normalization. |

### Manual QA checklist

- Install a clean release build.
- Launch with valid `.env`/dart-define values.
- Confirm Crashlytics initialization does not block startup.
- Sign in and sign out.
- Load Home and Explore with network available.
- Apply search, district, rating, price, and community filters.
- Open Map, change radius, select marker, persist/restore map view.
- Open cafe detail from Home, Explore, Map, Favorites, and Compare.
- Favorite/unfavorite a cafe online and after app restart.
- Add/remove compare cafes and confirm max four.
- Submit, update, delete a review.
- Test offline review submit and reconnect queue processing.
- Update profile and avatar with valid/invalid files.
- Admin add/edit/soft-delete/restore a cafe.
- Confirm soft-deleted cafe does not appear in Home/Explore/Map/detail search after refresh.
- Run direct Supabase RLS abuse checks.

### Debugging checklist

- Check `Env.hasSupabaseConfig`, `Env.hasGooglePlacesConfig`, and `Env.hasGoogleMapsConfig`.
- Check startup logs for `security-readiness-startup-*`.
- Run `SELECT public.app_security_readiness();`.
- Inspect `CafeState.cafeSyncState`, `cafesErrorMessage`, `cafesNoticeMessage`, and `isServingStaleCache`.
- Look for diagnostic log keys:
  - `cafe-diag-cache`
  - `cafe-diag-api`
  - `cafe-diag-merge`
  - `cafe-diag-delete-block`
  - `cafe-diag-photo-merge`
  - `places-rate-limit`
- Confirm `LocalStorageService` opened encrypted Hive successfully.
- Confirm Google Places API key is present and not placeholder.
- Confirm Google Cloud quotas are not exhausted.
- For stale/incorrect cafes, check Supabase row fields: `is_deleted`, `deleted_at`, `owner_approval_status`, `google_place_id`, name, coordinates.
- For review failures, check frontend cooldown, backend trigger, RLS, and `cafe_reviews` unique index.

### Glossary

| Term | Meaning |
| --- | --- |
| App-managed fields | Supabase-owned fields that can override Google metadata when `Cafe.usesAppManagedFields` is true. |
| Canonical identity | Stable merge key for matching Google and Supabase cafe records. |
| Discoverable baseline | Supabase cafes fetched during district/empty-Google discovery to supplement Google results. |
| Overlay row | Supabase cafe row fetched by Google place ID to override or block a Google candidate. |
| Soft delete | Admin update that marks a cafe deleted without physically deleting the row. |
| Delete block | Client merge rule that prevents a deleted/hidden/non-approved Supabase cafe from reappearing through Google Places. |
| L1 cache | In-memory repository/service cache for active session speed. |
| L2 cache | Encrypted Hive persistent cache for startup/offline hydration. |
| Stale-while-refresh | UI displays stale but usable cache while a remote refresh runs. |
| RLS | Supabase/Postgres Row Level Security; the authoritative access-control boundary. |
| Readiness gate | `app_security_readiness()` check used to verify critical RLS setup before release/admin mutation. |
| Dead letter | Offline queue entry that failed permanently or exceeded retry handling. |
