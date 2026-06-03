# Public Release Runbook

This runbook is the execution order for shipping KafeProje to public production on Android and iOS.

## 1. Freeze And Clean The Repo

1. Confirm the release branch is current.
2. Remove accidental local artifacts such as root `package.json` and `package-lock.json` unless intentionally adopted.
3. Run:

```powershell
flutter analyze
flutter test
powershell ./scripts/validate_release_readiness.ps1
```

4. Fix any script failure before building release candidates.

## 2. Configure Secrets Locally Or In CI

Android signing can use `android/key.properties` or environment variables:

- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

App runtime config must be supplied through dart defines:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_MAPS_API_KEY`
- `GOOGLE_PLACES_API_KEY`
- `GOOGLE_PLACES_PHOTO_API_KEY` if using a separate photo key

iOS Maps SDK config must be supplied through an ignored local file:

```powershell
Copy-Item ios/Flutter/ReleaseSecrets.xcconfig.example ios/Flutter/ReleaseSecrets.xcconfig
```

Then replace the placeholder with the iOS-restricted Maps key.

## 3. Build Android Release Candidate

```powershell
flutter build appbundle --release --dart-define-from-file=.env.local.json
```

Expected output:

- `build/app/outputs/bundle/release/app-release.aab`

Block release if signing, Maps, Places, Supabase config, or startup smoke fails.

## 4. Build iOS Release Candidate

On macOS with Xcode:

```bash
flutter build ios --release --no-codesign --dart-define-from-file=.env.local.json
```

Then open `ios/Runner.xcworkspace`, select the production team/provisioning, archive, export, and upload to TestFlight.

Block release if `ios/Flutter/ReleaseSecrets.xcconfig` is missing, the Maps key is unresolved, signing fails, or TestFlight install/startup fails.

## 5. Deploy Backend Release Candidate

Deploy Supabase migrations and Edge Functions to the production project:

```powershell
supabase db push
supabase functions deploy invite-cafe-owner
supabase functions deploy owner-invite
```

Configure required function secrets in Supabase:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OWNER_INVITE_REDIRECT_URL`

Run:

```sql
select public.app_security_readiness();
```

Release can proceed only when `is_ready = true`.

## 6. Run Live Release Smoke

Use `RELEASE_CHECKLIST.md`, `release-evidence/LIVE_SECURITY_INTEGRITY_SMOKE_CHECK.md`, and `supabase/SECURITY_READINESS.md`.

Required manual coverage:

- Auth sign up/sign in/sign out.
- Explore, map/location, cafe detail/images, favorites, compare, settings.
- Admin add/edit/delete/restore.
- Cafe owner invite and owner landing page.
- Local notification permission plus immediate and scheduled notification.
- Firebase Analytics events and privacy payload check.
- Crashlytics startup health.
- RLS malicious-client denial checks.
- Google API key restriction and quota verification.

## 7. Store Submission

1. Complete `docs/STORE_SUBMISSION_CHECKLIST.md`.
2. Publish the privacy policy at a stable URL.
3. Fill Google Play Data Safety and Apple Privacy Nutrition forms.
4. Upload Android AAB and iOS archive/TestFlight build.
5. Add reviewer notes and test credentials.
6. Submit first to internal/closed review if possible, then promote to public production after smoke signoff.
