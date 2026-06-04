# KafeProje

## Application Overview

KafeProje is a Flutter cafe discovery app for Istanbul. It combines app-managed cafe records from Supabase with Google Maps and Google Places data so signed-in users can discover cafes, view details, save favorites, compare cafes, and submit reviews.

The repository is not production-ready until the technical items in `Release To Do` are completed and verified against production-like services and real devices.

## User Walkthrough

1. Open the app. The initial route is the authentication screen unless an existing session is restored.
2. Sign in with an email or username and password, create an account with username, first name, last name, email, and password, or request a password reset from the sign-in form.
3. After authentication, use the bottom navigation to move between Home, Explore, Map, Favorites, and Profile.
4. Browse cafe cards on Home and Explore. Use search, filter, sorting, district filtering, and radius-based discovery where those controls are available.
5. Open the Map tab to view cafe markers and a bottom preview. Radius presets can narrow or broaden map discovery.
6. Open a cafe detail page to inspect images, ratings, opening hours, location information, reviews, and primary actions.
7. Add or remove cafes from Favorites. Selected favorite cafes are available from the Favorites tab.
8. Add cafes to the comparison list and open Compare from the floating compare action to review selected cafes side by side.
9. Submit a cafe review from the detail page. Existing review UI supports validation, loading/error states, review display, and delete actions for the review owner or admin.
10. Use Profile to view account details, edit profile fields and avatar, open Settings, or sign out.
11. Use Settings to change theme mode and language mode.
12. Admin users can open the Admin panel from Profile to add, edit, soft-delete, restore, feature, and assign/invite owners for cafes. Non-admin users are routed away from admin-only routes.

Owner claim data models, migrations, backend security hardening, and admin review UI exist in the repository, but owner claim screens are feature-gated with `ENABLE_OWNER_CLAIMS` and must be verified before release.

## Main Features

- Supabase authentication and profile management.
- Home, Explore, Map, Favorites, Profile, Settings, Compare, and Cafe Detail routes.
- Cafe search, filtering, district context, radius selection, sorting, and map/list flows.
- Google Places discovery and Google Maps display.
- Cafe image normalization for stored, Google Places, and direct trusted image sources.
- Favorites, compare list, local cache, offline queue, and sync status UI.
- Review submission, review listing, moderation helpers, ownership checks, and rate-limit support.
- Admin cafe management with route guards and Supabase RLS-backed authorization expectations.
- Turkish and English localization.
- Firebase Analytics and Crashlytics integration.
- Local notifications support.

## Technology Stack

- Flutter and Dart
- Riverpod / Flutter Riverpod
- GoRouter
- Supabase Auth, Postgres, Storage, Row Level Security, and Edge Functions
- Google Maps Flutter and Google Places HTTP APIs
- Hive, Flutter Secure Storage, cached network images, and cache manager
- Firebase Core, Analytics, and Crashlytics
- Flutter Local Notifications and timezone
- `flutter_dotenv` plus Dart defines for runtime configuration

## Local Setup

Install Flutter for your target platform, then fetch dependencies:

```powershell
flutter pub get
```

Create local runtime configuration from the placeholder example:

```powershell
Copy-Item .env.local.json.example .env.local.json
```

Fill `.env.local.json` with local development values. Do not commit real credentials, real service URLs, signing files, or Firebase app config.

Run the app with Dart defines:

```powershell
flutter run --dart-define-from-file=.env.local.json
```

Or use the helper script:

```powershell
powershell ./scripts/run_dev.ps1
```

Pass additional Flutter arguments through the helper when needed:

```powershell
powershell ./scripts/run_dev.ps1 -d chrome
```

For iOS release builds, copy the ignored release secrets example and set the restricted iOS Maps key locally:

```powershell
Copy-Item ios/Flutter/ReleaseSecrets.xcconfig.example ios/Flutter/ReleaseSecrets.xcconfig
```

## Environment Variables

Required runtime names:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_MAPS_API_KEY`
- `GOOGLE_PLACES_API_KEY`

Optional runtime name:

- `GOOGLE_PLACES_PHOTO_API_KEY`

Feature flag:

- `ENABLE_OWNER_CLAIMS`

Supabase Edge Function secret names used by owner invitation flows:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OWNER_INVITE_REDIRECT_URL`

Never put real values for these names in tracked files. Keep `.env`, `.env.local.json`, `ios/Flutter/ReleaseSecrets.xcconfig`, Android signing files, and Firebase local config ignored.

## Testing Instructions

Run formatting, analysis, and tests:

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run the repository release-readiness validation script:

```powershell
powershell ./scripts/validate_release_readiness.ps1
```

On the machine used for signed release builds, require local release secrets:

```powershell
powershell ./scripts/validate_release_readiness.ps1 -RequireLocalSecrets
```

Build Android release output with local Dart defines:

```powershell
flutter build apk --release --dart-define-from-file=.env.local.json
```

For app store submission, use an Android App Bundle:

```powershell
flutter build appbundle --release --dart-define-from-file=.env.local.json
```

iOS release builds must be performed on macOS with signing configured in Xcode:

```bash
flutter build ios --release --no-codesign --dart-define-from-file=.env.local.json
```

## Release To Do

- [ ] Re-run a complete tracked-file secret scan before publishing the repository.
- [ ] Rotate any Supabase, Google, Firebase, webhook, or function values that were ever present in local files, logs, screenshots, generated builds, or previous commits.
- [ ] Confirm Git history does not expose private API values or private project URLs, or rotate affected values before public launch.
- [ ] Configure a separate production Supabase project, database, storage buckets, RLS policies, Edge Function secrets, and backups.
- [ ] Verify the mobile app uses only the Supabase anon key and never contains the Supabase service role key.
- [ ] Restrict production Google Maps and Google Places keys by Android package/SHA, iOS bundle ID, enabled APIs, quotas, and monitoring.
- [ ] Create separate test accounts for normal user and admin roles; create cafe owner test accounts only if owner flows are enabled for release.
- [ ] Test sign-up, sign-in, sign-out, password reset, session restore, and duplicate-account behavior.
- [ ] Implement or verify an in-app account deletion flow and confirm related user data handling.
- [ ] Verify role and permission behavior for normal user, admin, and cafe owner roles if owner flows are enabled.
- [ ] Verify owner claim submission, duplicate claim prevention, admin approve/reject, owner assignment, and owner-only edit permissions if owner claims are enabled.
- [ ] Test review creation, validation, ownership delete behavior, rate limits, and moderation/reporting expectations.
- [ ] Test error, loading, empty, offline, slow-network, and sync retry states across Home, Explore, Map, Favorites, Compare, Profile, Admin, and detail screens.
- [ ] Verify Android and iOS permissions for location, photos, notifications, network access, and Maps SDK usage.
- [ ] Verify release build signing, version/build number configuration, ProGuard/R8 behavior, and production Dart defines.
- [ ] Run automated tests and address all failures before tagging a release.
- [ ] Run manual testing on at least one real Android device and on a real iPhone before iOS release.
- [ ] Run final production smoke tests against production services using non-sensitive demo data.

## Security Notes

- Supabase RLS is the authoritative security boundary; app route guards are UX controls only.
- Google Maps and Places keys in mobile apps are not secret by design; release safety depends on platform restrictions, API scoping, quotas, monitoring, and rotation.
- Analytics payloads should remain privacy-minimized and must not include email, display name, review text, raw search text, exact coordinates, full addresses, or user-identifying fields.
- The cafe table uses `google_place_id`; do not add or query a non-existent `place_id` column for current cafe flows.

## Supporting Documentation

- Local configuration details: `docs/LOCAL_ENV_RUN.md`
- Supabase/RLS audit guidance: `supabase/SECURITY_READINESS.md`
- RLS evidence template: `security-evidence/rls-audit/RELEASE_EVIDENCE_TEMPLATE.md`

## License

No open-source license is currently declared. Add a license before making the repository public if external reuse should be allowed.
