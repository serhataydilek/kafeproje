# Public Launch Software, Security, and Manual Test Checklist

This checklist is the single technical release-readiness source for the public Android and iOS launch.

Labels:

- **ZORUNLU:** Must be completed before public launch.
- **KAPSAMA GİRERSE ZORUNLU:** Must be completed if the feature exists in the release scope.
- **GÜÇLÜ TAVSİYE:** Not always mandatory for the first release, but skipping it increases operational risk.
- **NO-GO:** If any item fails, public launch must not proceed.

## 1. Technical Go / No-Go

- [ ] **ZORUNLU** Production environment is separated from development/test.
- [ ] **ZORUNLU** Production Supabase project is configured correctly.
- [ ] **ZORUNLU** Release builds can be produced for Android and iOS.
- [ ] **ZORUNLU** The app opens after a clean install.
- [ ] **ZORUNLU** Main flows have no crashes.
- [ ] **ZORUNLU** Broken or no-op buttons are removed.
- [ ] **ZORUNLU** Test/dummy screens are not visible in the production build.
- [ ] **ZORUNLU** Admin or debug features are not visible to normal users.
- [ ] **ZORUNLU** Test/debug code does not write data to the production database.
- [ ] **ZORUNLU** The app has an account deletion path.
- [ ] **ZORUNLU** The app has a privacy policy link.
- [ ] **ZORUNLU** The app has support contact information or a support link.

## 2. Test and Review Accounts

### Required Accounts

- [ ] **ZORUNLU** Normal user test account is ready.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Cafe owner account is ready.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin test account is ready.
- [ ] **ZORUNLU** Working demo login credentials are ready for app review teams.
- [ ] **ZORUNLU** Demo accounts do not use real personal data.
- [ ] **ZORUNLU** Demo account passwords are stable and accessible.
- [ ] **ZORUNLU** Demo accounts do not require OTP, SMS verification, or extra security that blocks review.
- [ ] **ZORUNLU** Main app features are visible with the demo user.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Demo cafe owner account is linked to a demo cafe.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin account can safely operate only on demo data.

### Recommended Extra Accounts

- [ ] **GÜÇLÜ TAVSİYE** Empty new user account.
- [ ] **GÜÇLÜ TAVSİYE** User account with prepared favorites and reviews.
- [ ] **GÜÇLÜ TAVSİYE** Account with a pending claim.
- [ ] **GÜÇLÜ TAVSİYE** Separate account for account deletion testing.
- [ ] **GÜÇLÜ TAVSİYE** Second owner account linked to another cafe for authorization testing.

## 3. Registration, Login, and Account Flow

- [ ] **ZORUNLU** New user can sign up.
- [ ] **ZORUNLU** User can sign in.
- [ ] **ZORUNLU** User can sign out.
- [ ] **ZORUNLU** Previous user data is not visible after logout.
- [ ] **ZORUNLU** A second account cannot be created with the same email.
- [ ] **ZORUNLU** Invalid email and invalid password messages are shown correctly.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Email verification flow works.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Forgot password flow works.
- [ ] **ZORUNLU** User can view profile information.
- [ ] **KAPSAMA GİRERSE ZORUNLU** User can edit profile information.
- [ ] **ZORUNLU** User can delete the account from inside the app.
- [ ] **ZORUNLU** Deleted account can no longer sign in.
- [ ] **ZORUNLU** Personal data is cleaned or anonymized as expected after account deletion.
- [ ] **ZORUNLU** Favorites, reviews, and claim links are checked after account deletion.
- [ ] **GÜÇLÜ TAVSİYE** Clear warning is shown before account deletion.

## 4. Main Cafe Discovery Flow

- [ ] **ZORUNLU** Home page loads cafes.
- [ ] **ZORUNLU** Cafe detail page opens.
- [ ] **ZORUNLU** Empty cafe fields do not break the UI.
- [ ] **ZORUNLU** Fallback image is shown when a cafe image is missing.
- [ ] **KAPSAMA GİRERSE ZORUNLU** App continues without crashing when Google Places images fail.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Search works.
- [ ] **KAPSAMA GİRERSE ZORUNLU** District filter works.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Radius filter works.
- [ ] **KAPSAMA GİRERSE ZORUNLU** District and radius filters do not break each other.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Map markers route to the correct cafe detail.
- [ ] **KAPSAMA GİRERSE ZORUNLU** List and map results are consistent.
- [ ] **ZORUNLU** Empty state is shown when no results are found.
- [ ] **ZORUNLU** API errors show understandable user-facing messages.
- [ ] **ZORUNLU** Loading state does not remain forever.
- [ ] **GÜÇLÜ TAVSİYE** Rapid filter changes do not let older results overwrite newer results.

## 5. Location Permission and Map

- [ ] **KAPSAMA GİRERSE ZORUNLU** Location permission reason is shown clearly to the user.
- [ ] **KAPSAMA GİRERSE ZORUNLU** App does not fully lock when location permission is denied.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Manual usage path exists without location permission.
- [ ] **KAPSAMA GİRERSE ZORUNLU** App recovers when location permission is enabled later.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Map opens without crashing.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Google Maps attribution is visible.
- [ ] **GÜÇLÜ TAVSİYE** Empty or incorrect-result scenario is tested when the user is in a different city.

## 6. Favorites and Comparison

- [ ] **KAPSAMA GİRERSE ZORUNLU** Cafe can be added to favorites.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Cafe can be removed from favorites.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Favorites persist after logout/login.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Favorite images are shown correctly.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Same cafe cannot be added to comparison twice.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Comparison limit, if any, shows a clear message.
- [ ] **GÜÇLÜ TAVSİYE** Favorite operations show a clear error on offline or weak connections.

## 7. Reviews and User Content

- [ ] **KAPSAMA GİRERSE ZORUNLU** User can write a review.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Empty review cannot be submitted.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Overly long review is limited.
- [ ] **KAPSAMA GİRERSE ZORUNLU** User can edit or delete their own review.
- [ ] **KAPSAMA GİRERSE ZORUNLU** User cannot modify another user's review.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Inappropriate review can be reported.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin can review reported reviews.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Review rules are accessible in the app or by link.
- [ ] **GÜÇLÜ TAVSİYE** User blocking or hiding mechanism exists for inappropriate content.

## 8. Cafe Owner Claim Flow

- [ ] **KAPSAMA GİRERSE ZORUNLU** Normal user can submit a claim.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Duplicate claims cannot be repeatedly submitted for the same cafe.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Claim status is correctly set to `pending`.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin can approve the claim.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin can reject the claim.
- [ ] **KAPSAMA GİRERSE ZORUNLU** After approval, `owner_user_id` is assigned to the correct user.
- [ ] **KAPSAMA GİRERSE ZORUNLU** After approval, user role becomes `cafe_owner`.
- [ ] **KAPSAMA GİRERSE ZORUNLU** After rejection, user sees an understandable status.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Cafe owner can edit only their own cafe.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Cafe owner cannot access another cafe by manually changing the cafe ID.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Normal user cannot call owner or admin RPCs.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Cafe owner cannot access admin features.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Claim documents are not publicly viewable.

## 9. Admin Panel and Authorization

- [ ] **KAPSAMA GİRERSE ZORUNLU** Non-admin user cannot access admin page.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Non-admin user cannot call admin RPCs.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin can view claim list.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Admin can approve/reject claims.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Same claim cannot be approved twice.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Accidental click risk is reduced for critical delete or approval actions.
- [ ] **GÜÇLÜ TAVSİYE** Admin operations are written to an audit log.
- [ ] **GÜÇLÜ TAVSİYE** MFA is enabled for admin account.

## 10. Supabase Security

- [ ] **ZORUNLU** RLS is enabled on all tables containing user data.
- [ ] **ZORUNLU** RLS policies are tested with normal user, owner, and admin roles.
- [ ] **ZORUNLU** `anon` role has only required read/write permissions.
- [ ] **ZORUNLU** `authenticated` role cannot access other users' data.
- [ ] **ZORUNLU** `service_role` key is not present in the mobile app.
- [ ] **ZORUNLU** Secret API keys or secrets are not embedded in the frontend/mobile bundle.
- [ ] **ZORUNLU** Storage bucket policies are checked.
- [ ] **ZORUNLU** User cannot read another user's profile, favorite, review, or claim data.
- [ ] **ZORUNLU** Cafe owner cannot read or edit another owner's data.
- [ ] **ZORUNLU** Non-admin roles cannot access admin tables.
- [ ] **GÜÇLÜ TAVSİYE** MFA is enabled for Supabase Dashboard account.
- [ ] **GÜÇLÜ TAVSİYE** Production backup and restore scenario is tested.

## 11. API Key and Repository Security

- [ ] **ZORUNLU** GitHub repository does not contain `.env` files.
- [ ] **ZORUNLU** GitHub repository does not contain a Supabase service key.
- [ ] **ZORUNLU** GitHub repository does not contain a Google API secret.
- [ ] **ZORUNLU** Previously leaked keys, if any, were rotated.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Google Maps API key is restricted by Android package and SHA.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Google Maps API key is restricted by iOS bundle ID.
- [ ] **GÜÇLÜ TAVSİYE** Separate API keys are used for Android, iOS, and backend.
- [ ] **GÜÇLÜ TAVSİYE** GitHub branch protection or direct-push control exists for main.

## 12. Device, Network, and UI Tests

- [ ] **ZORUNLU** Tested on at least one real Android phone.
- [ ] **ZORUNLU** Tested on at least one real iPhone.
- [ ] **ZORUNLU** App works on slow internet without crashing.
- [ ] **ZORUNLU** App shows understandable error when internet is disconnected.
- [ ] **ZORUNLU** App recovers when internet returns.
- [ ] **ZORUNLU** Important buttons do not disappear when keyboard opens.
- [ ] **ZORUNLU** Turkish and English text do not have critical overflow.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Deep links and email verification links work.
- [ ] **GÜÇLÜ TAVSİYE** Tested on different screen sizes.
- [ ] **GÜÇLÜ TAVSİYE** Accessibility test is done with large text size.
- [ ] **GÜÇLÜ TAVSİYE** Dark theme is tested separately if it exists.

## 13. Release Build Technical Checks

### Android

- [ ] **KAPSAMA GİRERSE ZORUNLU** Android App Bundle is created.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Release signing files are stored securely.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Package name is finalized.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Current target API requirement is met.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Production build is tested on a real device.

### iOS

- [ ] **KAPSAMA GİRERSE ZORUNLU** Bundle ID is finalized.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Signing and provisioning settings are correct.
- [ ] **KAPSAMA GİRERSE ZORUNLU** TestFlight build is tested on a real iPhone.
- [ ] **KAPSAMA GİRERSE ZORUNLU** Production build is tested on a real device.

## 14. Technical No-Go Items

Public launch must not proceed if any item below fails.

- [ ] **NO-GO** App crashes on clean install.
- [ ] **NO-GO** Normal user can access another user's data.
- [ ] **NO-GO** Cafe owner can edit another cafe.
- [ ] **NO-GO** Non-admin user can perform admin operations.
- [ ] **NO-GO** Account deletion does not work.
- [ ] **NO-GO** Review accounts do not work.
- [ ] **NO-GO** RLS is missing or untested.
- [ ] **NO-GO** Secret key exists in the mobile app or GitHub.
- [ ] **NO-GO** Review reporting/moderation flow is missing while review feature exists.
- [ ] **NO-GO** Real-device tests have not been completed.
