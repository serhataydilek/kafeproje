# KafeProje

KafeProje is a Flutter app for discovering, comparing, saving, and reviewing cafes in Istanbul. It combines app-managed cafe data from Supabase with live Google Places discovery, map data, ratings, opening hours, and photo metadata.

The app is built for mobile-first public release on Android and iOS. The codebase is release-candidate close, but public store publishing still requires production accounts, signing, restricted API keys, Supabase deployment, and real-device smoke testing.

## What The App Does

- Discover cafes from Home, Explore, and Map surfaces.
- Search, filter, and sort cafe results.
- View cafe details with photos, ratings, opening hours, location, and review context.
- Compare up to four cafes side by side.
- Save favorites with offline-tolerant local state.
- Submit and manage reviews with validation, moderation, duplicate checks, and backend rate limiting.
- Manage profile/auth flows with Supabase Auth.
- Support admin cafe add/edit/soft-delete/restore workflows.
- Support cafe owner invite and assignment flows through Supabase Edge Functions.
- Use Firebase Analytics and Crashlytics for production diagnostics.
- Support basic local notifications.

## Tech Stack

- Flutter / Dart
- Riverpod state management
- GoRouter navigation
- Supabase Auth, Postgres, Storage, RLS, and Edge Functions
- Google Maps and Google Places
- Firebase Analytics and Crashlytics
- Hive and Flutter Secure Storage for local persistence
- Flutter Local Notifications

## Repository Structure

```text
lib/
  config/          Environment and release config helpers
  constants/       App-wide constants
  models/          Cafe, user, review, result, and cache models
  navigation/      GoRouter setup and guards
  providers/       Riverpod state/controllers/selectors
  repositories/    Data orchestration and source merging
  screens/         Route-level UI
  services/        Supabase, Places, storage, analytics, notifications
  utils/           Validation, cache policy, logging, filtering, retry helpers
  widgets/         Reusable UI components

supabase/
  functions/       Edge Functions
  migrations/      Database migrations
  *.sql            Schema, RLS, readiness, review, and cafe support SQL

docs/
  LOCAL_ENV_RUN.md
  PUBLIC_RELEASE_RUNBOOK.md
  STORE_SUBMISSION_CHECKLIST.md
  FINAL_RELEASE_TODO.md
  PRIVACY_POLICY_DRAFT.md

release-evidence/
security-evidence/
  Release validation and RLS evidence templates/runbooks
```

## Local Setup

Install Flutter, then fetch dependencies:

```powershell
flutter pub get
```

Create local runtime config from your real development values:

```powershell
Copy-Item .env.local.json.example .env.local.json
```

Required keys:

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your_supabase_anon_key",
  "GOOGLE_MAPS_API_KEY": "your_google_maps_api_key",
  "GOOGLE_PLACES_API_KEY": "your_google_places_api_key"
}
```

Run the app:

```powershell
flutter run --dart-define-from-file=.env.local.json
```

Or use the helper:

```powershell
powershell ./scripts/run_dev.ps1
```

Do not commit `.env`, `.env.local.json`, signing files, or generated local secret config.

## Quality Checks

Run before committing release-sensitive changes:

```powershell
flutter analyze
flutter test
powershell ./scripts/validate_release_readiness.ps1
```

On the machine used for signed release builds, also require local iOS release secrets:

```powershell
powershell ./scripts/validate_release_readiness.ps1 -RequireLocalSecrets
```

## Android Release Build

Android release builds require:

- Production `.env.local.json`
- Restricted Google Maps and Places keys
- Supabase production URL and anon key
- Android release signing through `android/key.properties` or CI environment variables:
  - `ANDROID_KEYSTORE_PATH`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`

Build:

```powershell
flutter build appbundle --release --dart-define-from-file=.env.local.json
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## iOS Release Build

Copy the ignored release secrets example:

```powershell
Copy-Item ios/Flutter/ReleaseSecrets.xcconfig.example ios/Flutter/ReleaseSecrets.xcconfig
```

Set `GOOGLE_MAPS_API_KEY` in `ios/Flutter/ReleaseSecrets.xcconfig` to the iOS-restricted Maps SDK key.

On macOS:

```bash
flutter build ios --release --no-codesign --dart-define-from-file=.env.local.json
```

Then open `ios/Runner.xcworkspace`, configure Apple signing, archive, export, and upload through Xcode/TestFlight.

## Supabase Release Requirements

Before public release:

- Apply all migrations.
- Deploy Edge Functions:
  - `invite-cafe-owner`
  - `owner-invite`
- Configure function secrets:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `OWNER_INVITE_REDIRECT_URL`
- Confirm readiness:

```sql
select public.app_security_readiness();
```

Public release is blocked unless `is_ready = true`.

Use `supabase/SECURITY_READINESS.md` and `release-evidence/LIVE_SECURITY_INTEGRITY_SMOKE_CHECK.md` for live RLS/security validation.

## Release Status

Automated local checks are healthy, but the app is not public-store publishable until the external release gates are complete:

- Google Play and App Store Connect setup
- Android and iOS signing
- Restricted production API keys
- Supabase production deployment and RLS evidence
- Firebase Analytics/Crashlytics smoke checks
- Real-device Android and iOS manual smoke tests
- Privacy policy, store listing, screenshots, and data-safety/privacy forms

Use [docs/FINAL_RELEASE_TODO.md](docs/FINAL_RELEASE_TODO.md) as the final release checklist.

## Security And Privacy Notes

- Supabase RLS is the authoritative security boundary.
- Client route guards and validation are UX controls only.
- Google API keys in mobile apps are not secret; production release depends on platform restrictions, API scoping, quotas, and billing alerts.
- Analytics events are intentionally privacy-minimized and should not include email, display name, review text, raw search text, exact coordinates, or full addresses.
- See [docs/PRIVACY_POLICY_DRAFT.md](docs/PRIVACY_POLICY_DRAFT.md) before publishing store listings.

## License

No open-source license is currently declared. Add a license before making the repository public if external reuse should be allowed.
