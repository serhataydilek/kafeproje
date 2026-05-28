# Release Day 1 Checklist

**Date:** 2026-04-11
**Scope:** Day 1 only - freeze and bug list

## Feature Freeze

- [ ] Feature freeze announced
- [ ] New feature work stopped
- [ ] Only the following changes are allowed:
  - [ ] Bug fixes
  - [ ] Stability fixes
  - [ ] Release preparation
  - [ ] Simple notification system preparation only, if already in agreed release scope
- [ ] No new screens
- [ ] No new filters
- [ ] No large UI changes
- [ ] No data-model expansion unless required for a release-blocking fix
- [ ] No refactor without a linked bug ID

## Day 1 Goal

Lock release scope and collect all critical issues in one place.

## This Week's Allowed Work

- Bug fixes tied to this checklist
- Crash fixes
- Routing fixes
- State consistency fixes
- Release build fixes
- Minimal notification wiring only if already agreed in scope
- Copy-only changes for obvious mistakes
- Small safe UI fixes only when they resolve a logged bug

## This Week's Out-of-Scope Work

- New screens
- New filters or filter redesign
- Compare redesign
- Map UI redesign
- New ranking logic
- New admin workflows
- New analytics or dashboard work
- Large caching refactor
- New onboarding changes
- Any "quick improvement" that is actually a feature

## Manual Test Flows

Run these flows end to end and add every observed issue to the bug list below.

- [x] Release build open test
- [ ] Firebase Analytics release smoke
- [ ] Auth
- [ ] Explore
- [x] Map
- [ ] Cafe detail
- [x] Favorites
- [ ] Compare
- [ ] Admin add/edit/delete/restore
- [x] Settings
- [ ] Notification permission and scheduling smoke test (out of release scope)

### Featured/Sponsored Images (Manual)

- [ ] Home shows featured/sponsored cafe images when available.
- [ ] Featured/sponsored cards show image plus badge/frame together (badge does not cover the image).
- [ ] Featured/sponsored image placeholders look clean when images are missing.
- [ ] Verify featured/sponsored cards in both light and dark theme.

## Firebase Analytics Release Smoke

Run this manually against the release Firebase project. Do not add automated live Firebase tests for this release.

- [x] Android Firebase config readiness: `applicationId`, `android/app/google-services.json` package name, and Google Services Gradle plugin all use `com.kafeproje.app`.
- [x] Android release APK build: `flutter build apk --release` passed and produced `build/app/outputs/flutter-apk/app-release.apk`.
- [ ] Android manual Firebase DebugView/Realtime smoke is pending.
- [x] iOS Firebase config readiness: Runner bundle ID, `ios/Runner/GoogleService-Info.plist` `BUNDLE_ID`, and Runner target resources all use `com.kafeproje.app`.
- [ ] iOS macOS/Xcode build/signing is pending.
- [ ] iOS manual Firebase DebugView/Realtime smoke is pending.

Android manual Firebase smoke:

- [ ] Install `build/app/outputs/flutter-apk/app-release.apk` on a real Android device or emulator.
- [ ] Launch the app.
- [ ] Confirm `app_open` appears in Firebase DebugView or Realtime.
- [ ] Open a cafe detail page.
- [ ] Confirm `cafe_detail_opened` appears.
- [ ] Toggle favorite.
- [ ] Confirm `favorite_toggled` appears.
- [ ] Perform a search.
- [ ] Confirm `search_performed` appears and only logs `query_length`, not raw search text.
- [ ] Change map radius.
- [ ] Confirm `map_radius_changed` appears and only logs radius preset/value.
- [ ] Apply a filter.
- [ ] Confirm `filter_applied` appears and only logs a controlled category name or `unknown`.

iOS pending Firebase smoke:

- [ ] Run `flutter build ios --release --no-codesign` on macOS/Xcode.
- [ ] Open the Runner target in Xcode.
- [ ] Confirm signing team/provisioning for `com.kafeproje.app`.
- [ ] Install/run the iOS release build.
- [ ] Verify the same Firebase DebugView or Realtime events as Android.

Firebase Analytics privacy payload check:

- [ ] Must not log email, display name, review text, raw search text, exact coordinates, full addresses, or user-identifying fields.
- [ ] Allowed payloads are `cafe_id_hash`, `query_length`, radius preset/value, and a controlled filter category or `unknown`.
- [ ] macOS Analytics smoke is required only if `macos/Runner/GoogleService-Info.plist` exists for the release bundle ID. If present, build/run a release macOS app and repeat the approved event and payload checks above.

## Bug Priority Rules

- **P0:** Blocks release.
- **P1:** Release can ship, but the issue is embarrassing or high-friction.
- **P2:** Can be fixed after release.

## P0 Bugs

| ID | Flow | Issue | Repro Steps | Expected | Actual | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P0-001 | Admin / Explore / Map | Deleted cafe remains visible after admin delete | Delete a cafe in admin, then refresh Explore and Map | Deleted cafe should disappear everywhere public | Fixed in code: admin delete invalidates detail/home/featured/search/explore/map/admin providers, purges local identity variants, removes favorites/compare references, and tombstone filters hide deleted identities. Covered by `test/admin_screen_test.dart`. | Serhat | Fixed |
| P0-002 | Admin | Restored cafe appears as duplicate | Delete cafe, restore it, then search or open it from Explore and Map | Single restored record should appear | Duplicate entries appear | Serhat | Open |
| P0-003 | Favorites | Favorites state desyncs from actual cafe list | Favorite or unfavorite a cafe, refresh app or switch tabs | Favorite state stays correct across screens | Fixed in code: favorites hydrate by stable identity, remain resolvable offscreen, update counts optimistically, roll back on hard failure, and queue recoverable sync failures. Covered by `test/favorite_ux_test.dart`, `test/local_storage_service_test.dart`, and `test/offline_queue_service_test.dart`. | Serhat | Fixed |
| P0-004 | Compare | Compare state breaks or desyncs | Add cafes to compare, navigate away, return, remove one | Compare list should persist and update correctly | Fixed in code: compare selectors normalize stale IDs, keep remote/offscreen selections resolvable, persist through navigation, and remove stale items cleanly. Covered by `test/compare_flow_test.dart`. | Serhat | Fixed |
| P0-005 | Cafe detail | Detail opens wrong cafe | Open a cafe from Explore, Map, Favorites, or Compare | Correct cafe detail should open | Fixed in code: detail routes render local content for the requested id, Home/Map/Favorites/Compare entry points navigate to matching cafe detail, and unresolved ids fail honestly instead of showing the wrong cafe. Covered by `test/map_and_navigation_test.dart` and `test/compare_flow_test.dart`. | Serhat | Fixed |
| P0-006 | Cafe detail | Detail shows stale data after update, delete, or restore | Edit cafe in admin, then open detail | Updated detail should show current data | Old data is shown | Serhat | Open |
| P0-007 | Router / Auth | Router redirects to wrong place | Log in, log out, deep navigate, reopen app | App should land on correct route every time | Fixed in code: auth guard preserves safe `from` redirects, rejects unsafe redirects, handles unresolved admin role without premature downgrade, and protects admin/add routes correctly. Covered by `test/navigation/app_router_test.dart`, `test/auth_screen_test.dart`, and navigation back/source-route tests. | Serhat | Fixed |
| P0-008 | App startup | App crashes or release build does not open | Install and run release build on Android emulator, launch app, inspect startup state and fatal log output | App should open and reach stable home or auth entry | Not reproduced in release-open smoke: APK installed, launched, showed Home content, process stayed alive, and no startup fatal crash was observed in captured log window | Serhat | Not reproduced |
| P0-009 | Notifications | Notification permission and scheduling smoke test not validated yet | Trigger notification permission flow and basic schedule test | Permission and scheduling should work or fail gracefully | Not yet validated; no pass/fail result recorded | Serhat | Unverified |

## P1 Bugs

| ID | Flow | Issue | Repro Steps | Expected | Actual | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1-001 | Explore | Too few cafes shown due to merge or filter issues | Open Explore in an expected populated area | Real cafes should appear consistently | List is obviously under-populated | Serhat | Open |
| P1-002 | Explore / Map | Non-cafe places slip into results | Load venues in mixed districts | Only real cafes should appear | Pide, borek, pizza, or similar places appear | Serhat | Open |
| P1-003 | Map | Marker tap behavior is wrong | Tap map marker repeatedly | Marker should center and select cleanly | Fixed in code: marker taps select the latest cafe, place-id selections resolve correctly, stale selection clears on first open, and selected sheet actions remain usable on narrow layouts. Covered by `test/map_and_navigation_test.dart`. | Serhat | Fixed |
| P1-004 | Compare | Compare table layout is hard to use | Add multiple cafes and compare on mobile | Table should remain readable and actionable | Fixed in code: compare table uses an attribute-left matrix, compact icon-only feature column, stable slot/header sizing, and narrow-screen overflow coverage. Covered by `test/compare_flow_test.dart`. | Serhat | Fixed |
| P1-005 | Admin | Delete or restore buttons can be triggered multiple times | Tap destructive action repeatedly on slow network | Action should lock during request | Fixed in code: delete/restore actions are keyed by cafe id, disabled while pending, and duplicate controller calls are suppressed. Covered by `test/admin_screen_test.dart`. | Serhat | Fixed |
| P1-006 | Images | Cafe images missing or incomplete | Open several cafe details with photos | Images should load consistently | Fixed in code: featured/favorite images hydrate from matching cached rows, generated/stale Places media is replaced or falls back cleanly, carousels fail over to later candidates, and no-image states render placeholders. Covered by `test/home_sponsored_cafes_test.dart`, `test/favorite_ux_test.dart`, and `test/map_and_navigation_test.dart`. | Serhat | Fixed |
| P1-007 | Filters | Empty-state handling is poor | Apply strict filters with no results | Clean empty state should show | Fixed in code: Explore, Home, Favorites, and Map empty/error states are covered, including clear-search/reset-filter CTAs and keyboard-safe layouts. Covered by `test/empty_state_test.dart` and `test/explore_empty_guidance_test.dart`. | Serhat | Fixed |
| P1-008 | Home / Favorites / Featured | Filter state leaks across sections | Change filters in one section, inspect another | Screen-local state should stay isolated | Fixed in code: Explore/Map filter changes do not narrow Home, Favorites, Compare, or Featured pools. Covered by `test/filter_context_isolation_test.dart`. | Serhat | Fixed |
| P1-009 | Compare | Compare opens blank from cafe detail | From a cafe detail screen, tap Compare and open the compare screen | Compare screen should show selected cafe state or comparison content | Fixed in code: detail Compare now adds the cafe and opens Compare with the selected cafe visible. Covered by `test/compare_flow_test.dart`. | Serhat | Fixed |
| P1-010 | Explore | Explore appears to show too few cafes | Open Explore after cafe data loads | Explore should show the expected populated cafe list | Cafe list appears under-populated | Serhat | Open |
| P1-011 | Admin Add | Cafe add flow fails | Open admin add flow, fill the form, submit | Cafe is added successfully, or the UI clearly shows which required fields are missing | Submission failed with "cafe could not be added"; likely missing insert id fixed in code, pending manual backend retest | Serhat | Pending retest |

## P2 Bugs

| ID | Flow | Issue | Repro Steps | Expected | Actual | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P2-001 | Logging | Debug logs are noisy in normal app use | Navigate through app during test | Logs should be quiet enough for useful debugging | Excess router or flogger noise | Serhat | Open |
| P2-002 | UI polish | Map preview or buttons feel visually rough | Open screens using map preview components | UI should feel consistent and polished | Corners, spacing, or controls feel unfinished | Serhat | Open |
| P2-003 | Performance | Filter or refresh feels slower than desired | Change district, radius, and open filters repeatedly | Fast refresh | Noticeable lag but still usable | Serhat | Open |
| P2-004 | Copy | Placeholder or fallback text feels unfinished | Inspect missing-data cases | Copy should be clean and intentional | Rough placeholders visible | Serhat | Open |
| P2-005 | Analyzer | Static analysis has cleanup warnings | Run `flutter analyze` | Analyzer should be clean before release | Fixed. `flutter analyze` now reports no issues. | Serhat | Closed |
| P2-006 | Release build | Release build emits CupertinoIcons font warning | Run `flutter build apk --release` | Release build should complete without asset warnings | Build succeeds, but Flutter warns it expected CupertinoIcons fonts and found only MaterialIcons; no direct `CupertinoIcons`, `cupertino_icons`, or `packages/cupertino_icons` references found in source or lockfile | Serhat | Open |
| P2-007 | Auth | Password field validates too early while username is being typed | Start typing the username on the auth screen before interacting with the password field | Password field should not show error styling until the password field is interacted with or form submission is attempted | Fixed in code: auth fields now autovalidate individually, and the untouched password field stays clean while typing the identifier. Covered by `test/auth_screen_test.dart`. | Serhat | Fixed |

## Baseline P0 Watchlist

Use this as a starting point while testing.

- [ ] Deleted cafe remains visible after admin delete
- [ ] Restored cafe appears as a duplicate
- [ ] Favorites state breaks or desyncs
- [ ] Compare state breaks or desyncs
- [ ] Detail opens the wrong cafe
- [ ] Detail shows stale data
- [ ] Router redirects to the wrong place
- [ ] App crashes
- [x] Release build does not open - not reproduced in release-open smoke

## Day 1 Done

- [x] Net bug list exists
- [x] This week's allowed work is clear
- [x] This week's out-of-scope work is clear
- [ ] All Day 1 manual flows have been tested or explicitly marked blocked

## Day 1 Execution Log

- [x] `flutter pub get` passed.
- [x] `flutter test` passed: 307 tests.
- [x] `flutter build apk --release` passed before and after analyzer cleanup.
- [x] Release APK generated: `build\app\outputs\flutter-apk\app-release.apk` at 59.6 MB.
- [x] `flutter analyze` is clean. P2-005 is closed.
- [x] Android emulator access is working. Available emulator: `Medium_Phone_API_36.1`; connected target: `emulator-5554`, Android 16 API 36.
- [x] Release APK installed on `emulator-5554` with `adb install -r`.
- [x] Previous release-open smoke launched the pre-production package. Re-run this smoke after replacing Firebase config for `com.kafeproje.app`.
- [x] Release-open smoke passed within observed scope: Home content was visible, the app process stayed alive, and no startup fatal crash was observed in the captured log window.
- [ ] Auth manual flow completed. Current result: P2-007 fixed in code and covered by widget regression; full manual release retest still pending.
- [ ] Explore manual flow completed. Current result: partially validated; Explore loads, but the cafe list appears under-populated. Logged as P1-010.
- [x] Map manual flow completed. Current result: passed by manual validation.
- [ ] Cafe detail manual flow completed. Current result: awaiting Serhat manual validation.
- [x] Favorites manual flow completed. Current result: passed by manual validation.
- [ ] Compare manual flow completed. Current result: P1-009 fixed in code and covered by widget regression; full manual release retest still pending.
- [ ] Admin add/edit/delete/restore manual flow completed. Current result: add flow is a confirmed bug; submission failed with "cafe could not be added". Missing insert id fixed in code and required-field feedback made reachable; manual backend retest and admin listing visibility validation still needed. Logged as P1-011.
- [x] Settings manual flow completed. Current result: passed by manual validation.
- [ ] Notification permission and scheduling smoke test completed. Current result: no Android notification permission prompt appears, but notifications are not confirmed release scope. Treat as out of release scope; do not implement during release freeze.

## Day 1 Blockers

- No current Android tooling blocker. Emulator access is working through `emulator-5554`.
- Remaining manual flows are intentionally not marked complete until Serhat validates them.

## Day 1 Decision Tags

| ID | Decision | Reason |
| --- | --- | --- |
| P0-008 | Ship with known issue | Release-open smoke did not reproduce a startup crash; broader manual flows remain pending. Reopen as P0 if Serhat reproduces startup crash, freeze, blank screen, or wrong entry route. |
| Notifications | Out of release scope | Repo evidence shows no notification dependency, permission, service, UI entry point, or request path; the checklist only allowed notification prep conditionally. Do not implement notification permission/scheduling during release freeze. |
| P1-011 | Fix before release unless admin add is cut from release scope | Admin add now has a confirmed submission failure. Escalate to P0 only if release depends on adding cafes through Admin before ship. |
| P2-005 | Fix before release | Fixed: analyzer is clean. |
| P2-006 | Ship with known issue | Release APK builds successfully. Warning is non-blocking and no safe direct source fix was identified during release-freeze investigation. |

## Day 1 Test Order

1. Release build open test
2. Auth
3. Explore
4. Map
5. Cafe detail
6. Favorites
7. Compare
8. Admin add/edit/delete/restore
9. Settings
10. Notification permission and scheduling smoke test

## End-of-Day Decision Rule

Every logged bug must be tagged with one of the following:

- **Fix before release**
- **Ship with known issue**
- **Out of release scope**
