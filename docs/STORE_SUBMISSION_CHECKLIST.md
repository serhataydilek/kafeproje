# Store Submission Checklist

Use this checklist for the first public Android and iOS release. Do not submit to public production until every required item is complete or explicitly accepted as a release risk.

## Accounts And App Records

- [ ] Google Play Console developer account is active.
- [ ] Google Play app record exists for package `com.kafeproje.app`.
- [ ] Apple Developer Program account is active.
- [ ] App Store Connect app record exists for bundle ID `com.kafeproje.app`.
- [ ] Support email is active and monitored.
- [ ] Public privacy policy URL is published and matches `docs/PRIVACY_POLICY_DRAFT.md` after review.

## Production Identity And Assets

- [ ] Final app display name is approved.
- [ ] Production app icon is installed for Android and iOS.
- [ ] Launch screen/splash is acceptable for release.
- [ ] Android phone screenshots are captured from a signed release build.
- [ ] iPhone screenshots are captured from a TestFlight/release build.
- [ ] Short description, full description, keywords, subtitle, and release notes are written.
- [ ] Content rating questionnaires are completed.

## Signing And Builds

- [ ] Android upload keystore is generated and stored securely.
- [ ] Android signing is configured through `android/key.properties` or CI secrets.
- [ ] Android signed AAB is built with production dart defines.
- [ ] Apple signing team and provisioning are configured in Xcode.
- [ ] `ios/Flutter/ReleaseSecrets.xcconfig` exists locally with the restricted iOS Google Maps key.
- [ ] iOS release archive exports successfully from Xcode.
- [ ] TestFlight build installs and launches.

## Production Service Configuration

- [ ] Firebase Android app uses package `com.kafeproje.app`.
- [ ] Firebase iOS app uses bundle ID `com.kafeproje.app`.
- [ ] Firebase Analytics DebugView or Realtime smoke passes on Android and iOS.
- [ ] Firebase Crashlytics receives startup/crash-free diagnostics on Android and iOS.
- [ ] Supabase production project URL and anon key are passed through dart defines.
- [ ] Supabase migrations are applied.
- [ ] Supabase Edge Functions `invite-cafe-owner` and `owner-invite` are deployed.
- [ ] Supabase Edge Function secrets are configured.
- [ ] `select public.app_security_readiness();` returns `is_ready = true`.
- [ ] RLS malicious-client evidence is saved under `security-evidence/rls-audit/`.

## API Keys

- [ ] Android Google Maps key is restricted to package `com.kafeproje.app` and release SHA certificate.
- [ ] Android Google Places key is restricted to package `com.kafeproje.app`, release SHA certificate, and required Places APIs.
- [ ] iOS Google Maps key is restricted to bundle ID `com.kafeproje.app` and Maps SDK for iOS.
- [ ] Places/photo key strategy is documented and restricted.
- [ ] Quotas and billing alerts are configured in Google Cloud.

## Privacy And Permissions

- [ ] Google Play Data Safety form matches the privacy policy and actual app behavior.
- [ ] Apple Privacy Nutrition answers match the privacy policy and actual app behavior.
- [ ] Location purpose is disclosed.
- [ ] Profile photo/gallery purpose is disclosed.
- [ ] Firebase Analytics/Crashlytics use is disclosed.
- [ ] Supabase auth/database/storage use is disclosed.
- [ ] Google Maps/Places use is disclosed.
- [ ] Local notification purpose is disclosed.
- [ ] Reviewer notes explain any login/admin test credentials.

## Release Smoke Signoff

- [ ] Android release startup/auth/explore/map/detail/favorites/compare/settings pass.
- [ ] Android admin add/edit/delete/restore passes against production-like Supabase.
- [ ] Android notification permission and immediate/scheduled notification smoke passes.
- [ ] iOS release startup/auth/explore/map/detail/favorites/compare/settings pass.
- [ ] iOS admin add/edit/delete/restore passes against production-like Supabase.
- [ ] iOS notification permission and immediate/scheduled notification smoke passes.
- [ ] Analytics payload privacy check passes on both platforms.
- [ ] Crashlytics startup check passes on both platforms.
