# Final Public Release Todo List

## A. Accounts

- [ ] Create Google Play Console account.
- [ ] Create Apple Developer account.
- [ ] Create Google Play app with package `com.kafeproje.app`.
- [ ] Create App Store Connect app with bundle ID `com.kafeproje.app`.

## B. Production Config

- [ ] Create production Supabase project or confirm current project is production.
- [ ] Apply all Supabase migrations.
- [ ] Deploy Supabase Edge Function `invite-cafe-owner`.
- [ ] Deploy Supabase Edge Function `owner-invite`.
- [ ] Set Supabase function secret `SUPABASE_URL`.
- [ ] Set Supabase function secret `SUPABASE_ANON_KEY`.
- [ ] Set Supabase function secret `SUPABASE_SERVICE_ROLE_KEY`.
- [ ] Set Supabase function secret `OWNER_INVITE_REDIRECT_URL`.
- [ ] Run:

```sql
select public.app_security_readiness();
```

- [ ] Confirm the result includes `is_ready = true`.

## C. API Keys

- [ ] Create restricted Android Google Maps key.
- [ ] Create restricted Android Google Places key.
- [ ] Create restricted iOS Google Maps key.
- [ ] Restrict Android keys by package `com.kafeproje.app`.
- [ ] Restrict Android keys by release SHA certificate.
- [ ] Restrict Android keys to required APIs only.
- [ ] Restrict iOS key by bundle ID `com.kafeproje.app`.
- [ ] Restrict iOS key to Maps SDK for iOS only.
- [ ] Add Google Cloud billing alerts.
- [ ] Add Google Cloud API quotas.

## D. Signing

- [ ] Generate Android upload keystore.
- [ ] Configure Android signing through `android/key.properties` or CI secrets.
- [ ] Set Apple Team in Xcode.
- [ ] Create iOS provisioning profiles/certificates.
- [ ] Confirm iOS archive/export works.

## E. Local Release Files

- [ ] Create `.env.local.json` with production values:

```json
{
  "SUPABASE_URL": "...",
  "SUPABASE_ANON_KEY": "...",
  "GOOGLE_MAPS_API_KEY": "...",
  "GOOGLE_PLACES_API_KEY": "..."
}
```

- [ ] Create iOS release secrets:

```powershell
Copy-Item ios/Flutter/ReleaseSecrets.xcconfig.example ios/Flutter/ReleaseSecrets.xcconfig
```

- [ ] Put the restricted iOS Google Maps key in `ios/Flutter/ReleaseSecrets.xcconfig`.

## F. Build

- [ ] Run:

```powershell
powershell ./scripts/validate_release_readiness.ps1 -RequireLocalSecrets
flutter analyze
flutter test
```

- [ ] Build Android AAB:

```powershell
flutter build appbundle --release --dart-define-from-file=.env.local.json
```

- [ ] Build iOS on macOS:

```bash
flutter build ios --release --no-codesign --dart-define-from-file=.env.local.json
```

- [ ] Archive/upload iOS from Xcode.

## G. Manual Smoke Test

- [ ] Test signed Android build.
- [ ] Test iOS TestFlight build.
- [ ] Test app startup.
- [ ] Test sign up.
- [ ] Test sign in.
- [ ] Test sign out.
- [ ] Test Explore.
- [ ] Test Map.
- [ ] Test location permission.
- [ ] Test cafe detail.
- [ ] Test cafe images.
- [ ] Test favorites.
- [ ] Test compare.
- [ ] Test profile photo upload.
- [ ] Test settings.
- [ ] Test notification permission.
- [ ] Test one immediate notification.
- [ ] Test one scheduled notification.
- [ ] Test admin add cafe.
- [ ] Test admin edit cafe.
- [ ] Test admin delete cafe.
- [ ] Test admin restore cafe.
- [ ] Test cafe owner invite.

## H. Firebase

- [ ] Confirm Firebase Android app package is `com.kafeproje.app`.
- [ ] Confirm Firebase iOS app bundle is `com.kafeproje.app`.
- [ ] Confirm Analytics event `app_open` appears.
- [ ] Confirm Analytics event `cafe_detail_opened` appears.
- [ ] Confirm Analytics event `favorite_toggled` appears.
- [ ] Confirm Analytics event `search_performed` appears.
- [ ] Confirm Analytics event `map_radius_changed` appears.
- [ ] Confirm Analytics event `filter_applied` appears.
- [ ] Confirm Analytics does not log email, display name, review text, raw search text, exact coordinates, or full addresses.
- [ ] Confirm Crashlytics is receiving data.

## I. Store Materials

- [ ] Final app icon.
- [ ] Final screenshots.
- [ ] Short description.
- [ ] Full description.
- [ ] Support email.
- [ ] Privacy policy URL.
- [ ] App category.
- [ ] Content rating.
- [ ] Release notes.
- [ ] Reviewer test account.
- [ ] Admin reviewer account if needed.

## J. Privacy And Compliance

- [ ] Publish privacy policy based on `docs/PRIVACY_POLICY_DRAFT.md`.
- [ ] Fill Google Play Data Safety.
- [ ] Fill Apple Privacy Nutrition.
- [ ] Disclose Firebase Analytics.
- [ ] Disclose Crashlytics.
- [ ] Disclose Supabase auth/database/storage.
- [ ] Disclose Google Maps/Places.
- [ ] Disclose location permission.
- [ ] Disclose profile photo upload.
- [ ] Disclose local notifications.

## K. Submit

- [ ] Upload Android AAB to Play Console.
- [ ] Upload iOS build to TestFlight/App Store Connect.
- [ ] Submit internal/closed test first.
- [ ] Fix anything found in internal/closed testing.
- [ ] Submit public production release.

## Main Blockers

- Accounts.
- Signing.
- Production keys.
- Supabase deployment.
- Manual smoke testing.
