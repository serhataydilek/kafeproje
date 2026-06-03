# KafeProje Privacy Policy Draft

Last updated: TODO

This draft is intended for the public production release of KafeProje. Review it with the actual production data flows, store disclosures, and legal requirements before publishing it at a stable public URL.

## Who We Are

KafeProje helps people discover, compare, save, and review cafes in Istanbul.

Contact: TODO support email

## Information We Collect

- Account information: email address, username, display/profile names, authentication identifiers, and profile photo if you add one.
- Cafe activity: saved favorites, compare selections stored locally, reviews you submit, and cafe ownership/admin actions where applicable.
- Location: approximate or precise device location only when you grant permission, used to show nearby cafes and map results.
- Photos: profile photos you choose from your device gallery for upload to your profile.
- App diagnostics: crash reports, app version, device/platform diagnostics, and minimal analytics events.
- Third-party place data: cafe details, map, and photo data returned by Google Maps and Google Places.
- Notifications: local notification permission state and local notification scheduling/delivery handled on your device.

## How We Use Information

- Provide account sign-in, profile, cafe discovery, favorites, reviews, and cafe owner/admin features.
- Show nearby cafes and map results when location permission is granted.
- Upload and display your profile photo if you choose to add one.
- Improve reliability using crash reports and privacy-minimized analytics.
- Protect the service with authorization checks, row-level security, rate limits, and abuse prevention.
- Send local notifications only when enabled by the app feature and permitted by the device.

## Analytics And Diagnostics

KafeProje uses Firebase Analytics and Firebase Crashlytics for production reliability. Analytics events are intentionally minimal. They may include hashed cafe identifiers, query length, radius values, and controlled filter categories. They must not include email, display name, review text, raw search text, exact coordinates, or full addresses.

## Third-Party Services

- Supabase: authentication, database, storage, and Edge Functions.
- Firebase: Analytics and Crashlytics.
- Google Maps and Google Places: maps, place search/details, and cafe photos.
- Device platform services: location, photo picker/gallery access, and local notifications.

These providers process data according to their own terms and privacy policies.

## Data Sharing

We do not sell personal information. Data is shared with service providers only as needed to run the app, provide maps/place data, authenticate users, store app data, deliver diagnostics, and comply with legal obligations.

## Your Choices

- You can deny or revoke location permission in device settings.
- You can deny or revoke notification permission in device settings.
- You can choose not to upload a profile photo or remove it in the app where supported.
- You can sign out from the app.
- For account or data deletion requests, contact TODO support email until an in-app deletion flow is available.

## Data Retention

Account, profile, review, favorite, and cafe owner/admin records are retained while your account or the relevant app content remains active, unless deletion is requested or required. Crash and analytics data retention follows Firebase project settings.

## Children

KafeProje is not intended for children under the age required by the app stores for this category. Do not use the app if you are not permitted to use online services in your region.

## Security

KafeProje uses Supabase row-level security, authenticated APIs, release key restrictions, and app-side safeguards. No system can be guaranteed completely secure.

## Changes

We may update this policy. The latest version should be available at the public privacy policy URL used in the app store listings.
