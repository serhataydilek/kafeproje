# Live Security And Integrity Smoke Check

Use this as the final pre-release verification runbook against the real Supabase project and real app build.

Scope covered in this runbook:
- admin vs non-admin mutation behavior
- cafe insert/update/delete/restore permissions
- featured cafe visibility and expiry behavior
- deleted cafe suppression
- review creation and rate-limit behavior
- favorites consistency basics
- public read boundaries
- readiness/security function checks already in repo

## 1. Preconditions

- Environment: production-like Supabase project used for release.
- App build: release candidate build (same env vars/secrets planned for release).
- Test users:
  - admin_user (role=admin)
  - non_admin_user (authenticated, non-admin)
  - anon (no session)
- Known cafe targets:
  - one stable visible cafe id for read/update checks
  - one disposable smoke cafe id prefix: `smoke-<yyyymmdd>-...`

Evidence output root:
- `security-evidence/rls-audit/<run-date>/`
- `release-evidence/<run-date>-security-integrity-notes.md` (optional summary note)

## 2. What The Repo Already Covers

These artifacts reduce risk before live checks:

- Cafe RLS readiness probe function and grants:
  - `supabase/security_readiness_function.sql`
- Cafe table RLS policies (public read + admin insert/update):
  - `supabase/cafe_optimizations_schema.sql`
- Existing malicious-client release evidence plan/template:
  - `supabase/SECURITY_READINESS.md`
  - `security-evidence/rls-audit/RELEASE_EVIDENCE_TEMPLATE.md`
- Reviews ownership and base RLS policies:
  - `supabase/cafe_reviews.sql`
- Reviews backend mutation rate-limit trigger:
  - `supabase/cafe_reviews_rate_limit.sql`
- Featured metadata schema/index:
  - `supabase/cafe_featured_fields.sql`
- App-level readiness probe integration:
  - `lib/services/supabase_service.dart`
  - `test/supabase_service_test.dart`
- Admin destructive-action gating and in-flight protection:
  - `test/admin_screen_test.dart`
- Featured and sponsored visibility/ordering behavior:
  - `test/home_sponsored_cafes_test.dart`
  - `test/model_parsing_test.dart`
- Deleted overlay suppression in merge flow:
  - `test/cafe_merge_policy_test.dart`
- Favorites optimistic + rollback consistency:
  - `test/favorite_ux_test.dart`

Important: the above is mostly unit/widget/static-migration confidence. Real authorization and data-integrity behavior must still be validated live.

## 3. Live Smoke Sequence (Release Gate)

Run in order. Stop release on any FAIL.

### SI-01 Readiness Function Gate

1. Run in SQL editor:

```sql
select public.app_security_readiness();
```

2. PASS only if JSON includes:
   - `is_ready = true`
   - `rls_enabled = true`
   - `has_admin_insert_policy = true`
   - `has_admin_update_policy = true`

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-01-readiness.json`

### SI-02 Non-Admin Cannot Mutate Cafes (Direct API)

Use `non_admin_user` JWT and attempt:
- insert cafe
- update existing cafe
- delete existing cafe
- update `is_deleted=true` (soft-delete style)

Expected:
- denied by backend auth/RLS (401/403/PostgREST denial)
- no row mutation

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-02-*.txt`

Reference scenarios:
- MC-01, MC-02, MC-03, MC-04 in `supabase/SECURITY_READINESS.md`

### SI-03 Anonymous And Expired Session Mutation Denial

Run:
- anonymous insert attempt
- expired JWT update attempt

Expected:
- denied
- no mutation

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-03-*.txt`

Reference scenarios:
- MC-05, MC-06 in `supabase/SECURITY_READINESS.md`

### SI-04 Admin Mutation Happy Path (Real App)

Login as admin in release app and verify:
- add cafe succeeds (disposable smoke cafe)
- edit cafe succeeds
- delete cafe succeeds
- restore cafe succeeds

Expected:
- each mutation result is reflected in backend row state
- no duplicate rows after restore

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-04-admin-mutations.md`
- optional exported row snapshots before/after

### SI-05 Non-Admin UI Guard + Backend Guard

Login as non-admin user in app:
- confirm admin mutation controls are unavailable or blocked
- if any direct mutation path is reachable, operation must still fail

Expected:
- no non-admin mutation succeeds

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-05-non-admin-app-guard.md`

### SI-06 Featured Visibility And Expiry Integrity

Using admin:
- set Cafe A: `is_featured=true`, future `featured_until`, priority high
- set Cafe B: `is_featured=true`, past `featured_until`
- set Cafe C: featured but `is_deleted=true` or non-approved status

Validate in Home sponsored section:
- Cafe A appears
- Cafe B does not appear (expired)
- Cafe C does not appear (deleted/hidden)

Expected:
- sponsored section includes only active featured cafes

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-06-featured-visibility.md`

### SI-07 Deleted Cafe Suppression Across Public Surfaces

Delete one cafe as admin, then verify:
- Explore list
- Home lists/sponsored
- Map markers/list
- direct public read query (anon)

Expected:
- deleted cafe is absent everywhere public

Then restore same cafe:
- appears again once (no duplication)

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-07-delete-restore-visibility.md`

### SI-08 Review Ownership + Rate Limit Enforcement

As authenticated non-admin user:
- submit one review (should pass)
- submit second mutation immediately (update/delete/submit) within 30s

Expected:
- backend rate-limit enforcement blocks second mutation window
- app surfaces rate-limit/validation outcome cleanly

Ownership checks:
- second user attempts to edit/delete first user review
- expected denied (not owner/RLS)

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-08-reviews.md`

### SI-09 Favorites Consistency Basics

As authenticated user:
- toggle favorite from at least two surfaces (card + detail)
- confirm favorites screen membership matches state
- refresh/reopen app and verify persistence
- verify `favorite_count` does not show contradictory behavior after sync

Expected:
- no phantom favorites
- no persistent desync after sync completion

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-09-favorites.md`

### SI-10 Public Read Boundaries

As anon:
- read discoverable cafes endpoint/query

Expected:
- read works for public discovery
- no ability to write cafes/reviews/favorites without valid auth and policy

Artifacts:
- `security-evidence/rls-audit/<run-date>/SI-10-public-read-boundary.md`

## 4. Pass/Fail Release Rule

Release PASS only if:
- SI-01 through SI-10 are all PASS.
- Every denied-write scenario is denied by backend (not just UI).
- Delete/restore, featured expiry, and favorites/reviews checks show no integrity regressions.

Release BLOCK if any of these occur:
- non-admin/anon mutation succeeds
- readiness function reports unhealthy
- deleted cafes leak into public surfaces
- featured expiry logic behaves inconsistently in live data
- review ownership or rate-limit guard fails

## 5. Practical Timebox

Target execution time: 45 to 75 minutes per release candidate.

Suggested order:
1. SI-01
2. SI-02 + SI-03 (direct API denials)
3. SI-04 + SI-05 (app-role mutation behavior)
4. SI-06 + SI-07 (featured + deletion integrity)
5. SI-08 + SI-09 + SI-10 (reviews, favorites, public reads)
