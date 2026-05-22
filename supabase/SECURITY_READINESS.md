# Security Readiness And Malicious-Client Audit Evidence

This document is the release-evidence plan for validating Supabase RLS and admin authorization boundaries against malicious-client behavior.

## 1) Baseline readiness gate

This app uses a runtime database probe, `public.app_security_readiness()`, to verify required `cafes` RLS setup.

Required migration files:
- `supabase/cafe_optimizations_schema.sql`
- `supabase/security_readiness_function.sql`

Required SQL gate:

```sql
SELECT (public.app_security_readiness()->>'is_ready')::boolean AS is_ready;
```

Expected gate result:
- `true`

Example deployment gate:

```sh
RESULT=$(psql "$DATABASE_URL" -t -A -c "SELECT (public.app_security_readiness()->>'is_ready')::boolean")
if [ "$RESULT" != "t" ] && [ "$RESULT" != "true" ]; then
  echo "Security readiness check failed"
  exit 1
fi
```

Runtime guard behavior expected in app:
- Startup warns when readiness is unhealthy.
- Destructive admin mutations (delete/restore) are blocked while readiness is unhealthy.

## 2) Malicious-client audit objective

Prove that backend authorization holds even when UI route guards are bypassed and requests are sent directly to Supabase APIs.

Minimum threat coverage:
1. Non-admin attempting admin-only insert/update/delete.
2. Direct API attempts that bypass app navigation guards.
3. Anonymous and expired-session write attempts.
4. Select access boundary checks for public discovery behavior.

## 3) Preconditions and test identities

Required test identities:
- `admin_user`: profile role resolves to `admin`.
- `non_admin_user`: profile role resolves to non-admin.
- `anon`: unauthenticated caller.
- `expired_session`: previously valid JWT that is now expired.

Required environment values:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `TARGET_CAFE_ID` (existing cafe row id)

Evidence storage convention:
- Save each scenario output under `security-evidence/rls-audit/<scenario-id>/`.
- Include request payload, status code, response body, and UTC timestamp.

## 4) Exact attack scenarios

### MC-01: Non-admin tries direct INSERT on cafes
Attack:
- Use `non_admin_user` JWT to insert a cafe row through PostgREST.

Expected outcome:
- Request denied by RLS.
- HTTP 401/403-style denial or PostgREST policy error.

Pass criteria:
- No row created.
- Response contains authorization/policy denial.

### MC-02: Non-admin tries direct UPDATE on cafes
Attack:
- Use `non_admin_user` JWT to update `name` on `TARGET_CAFE_ID`.

Expected outcome:
- Request denied by RLS.
- No data mutation.

Pass criteria:
- Update returns denied or zero permitted rows.
- Post-check confirms original row remains unchanged.

### MC-03: Non-admin tries direct DELETE on cafes
Attack:
- Use `non_admin_user` JWT to send `DELETE` for `TARGET_CAFE_ID`.

Expected outcome:
- Request denied (no delete policy granted to non-admin).

Pass criteria:
- Row remains present.
- Response denied by policy/authorization.

### MC-04: Non-admin bypasses UI and attempts soft-delete semantics via UPDATE
Attack:
- Use `non_admin_user` JWT to directly set `is_deleted=true` on `TARGET_CAFE_ID`.

Expected outcome:
- Request denied by admin-only update policy.

Pass criteria:
- `is_deleted` stays unchanged.
- Response denied by policy/authorization.

### MC-05: Anonymous caller attempts INSERT
Attack:
- No `Authorization` bearer token, only anon key.

Expected outcome:
- Request denied.

Pass criteria:
- No row created.
- Response denied for unauthenticated caller.

### MC-06: Expired JWT attempts UPDATE
Attack:
- Use expired bearer token to update `TARGET_CAFE_ID`.

Expected outcome:
- Session invalid/expired denial before mutation.

Pass criteria:
- No data mutation.
- Response indicates expired/invalid JWT.

### MC-07: Direct API bypass proof (route guard bypass)
Attack:
- Execute MC-01/02/04 with curl or JS script from outside app process.

Expected outcome:
- Same denials as in-app calls, proving backend guard is authoritative.

Pass criteria:
- Denial occurs even without app routing logic involved.

### MC-08: Select access boundary check for cafes
Attack:
- Call `SELECT` on cafes as anon and as authenticated non-admin.

Expected outcome:
- Reads succeed by design for public discovery policy.

Pass criteria:
- Read allowed.
- No unexpected write permissions granted in same session.

## 5) Test execution steps

### Step A: Confirm readiness probe

Run:

```sql
SELECT public.app_security_readiness();
```

Record:
- full JSON payload
- timestamp
- environment name

### Step B: Acquire JWTs

Non-admin token:

```sh
curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"NON_ADMIN_EMAIL","password":"NON_ADMIN_PASSWORD"}'
```

Admin token (for control checks, optional but recommended):

```sh
curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"ADMIN_EMAIL","password":"ADMIN_PASSWORD"}'
```

### Step C: Run scenario requests with direct PostgREST calls

Non-admin insert attempt (MC-01):

```sh
curl -i -X POST "$SUPABASE_URL/rest/v1/cafes" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $NON_ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"name":"Malicious Insert Attempt","neighborhood":"Test"}'
```

Non-admin update attempt (MC-02):

```sh
curl -i -X PATCH "$SUPABASE_URL/rest/v1/cafes?id=eq.$TARGET_CAFE_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $NON_ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"name":"Malicious Update Attempt"}'
```

Non-admin delete attempt (MC-03):

```sh
curl -i -X DELETE "$SUPABASE_URL/rest/v1/cafes?id=eq.$TARGET_CAFE_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $NON_ADMIN_JWT"
```

Non-admin soft-delete style update attempt (MC-04):

```sh
curl -i -X PATCH "$SUPABASE_URL/rest/v1/cafes?id=eq.$TARGET_CAFE_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $NON_ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"is_deleted":true,"deleted_at":"2026-04-05T00:00:00Z"}'
```

Anonymous insert attempt (MC-05):

```sh
curl -i -X POST "$SUPABASE_URL/rest/v1/cafes" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"Anon Insert Attempt","neighborhood":"Test"}'
```

Expired token update attempt (MC-06):

```sh
curl -i -X PATCH "$SUPABASE_URL/rest/v1/cafes?id=eq.$TARGET_CAFE_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $EXPIRED_JWT" \
  -H "Content-Type: application/json" \
  -d '{"name":"Expired Token Attempt"}'
```

Select boundary check (MC-08):

```sh
curl -i "$SUPABASE_URL/rest/v1/cafes?select=id,name,is_deleted&limit=5" \
  -H "apikey: $SUPABASE_ANON_KEY"
```

### Step D: Post-checks

After each denied write scenario:
1. Re-read `TARGET_CAFE_ID` with admin credentials.
2. Confirm target fields are unchanged.
3. Save before/after payload snapshots.

## 6) Optional JS/Supabase validation snippet

```js
import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL
const anonKey = process.env.SUPABASE_ANON_KEY
const token = process.env.NON_ADMIN_JWT
const cafeId = process.env.TARGET_CAFE_ID

const client = createClient(url, anonKey, {
  global: { headers: { Authorization: `Bearer ${token}` } }
})

const attempt = await client
  .from('cafes')
  .update({ is_deleted: true })
  .eq('id', cafeId)
  .select('id,is_deleted')

console.log({ data: attempt.data, error: attempt.error })
// Release pass expectation: error present, data null/empty
```

## 7) Concise pass/fail matrix

| ID | Scenario | Expected result | Release verdict rule |
|---|---|---|---|
| MC-01 | Non-admin INSERT cafes | Denied | PASS if denied and no row created |
| MC-02 | Non-admin UPDATE cafes | Denied | PASS if denied and row unchanged |
| MC-03 | Non-admin DELETE cafes | Denied | PASS if denied and row still exists |
| MC-04 | Non-admin soft-delete style UPDATE | Denied | PASS if denied and is_deleted unchanged |
| MC-05 | Anonymous INSERT cafes | Denied | PASS if denied and no row created |
| MC-06 | Expired JWT UPDATE cafes | Denied | PASS if denied and row unchanged |
| MC-07 | Direct API route-guard bypass | Denied | PASS if same backend denials as MC-01/02/04 |
| MC-08 | Public SELECT cafes boundary | Allowed read only | PASS if reads succeed but writes remain denied |

Release signoff condition:
- All denial scenarios (MC-01 to MC-07) must pass.
- Public read boundary (MC-08) must behave as expected.

## 8) Evidence format for release notes

Use one evidence block per scenario:

```md
Scenario: MC-02
Actor: non_admin_user
Timestamp UTC: 2026-04-05T14:12:40Z
Endpoint: PATCH /rest/v1/cafes?id=eq.<TARGET_CAFE_ID>
Expected: denied by RLS
Observed: HTTP 401, body contains authorization/policy denial
Post-check: target row name unchanged
Verdict: PASS
Artifacts:
- security-evidence/rls-audit/MC-02/request.txt
- security-evidence/rls-audit/MC-02/response.txt
- security-evidence/rls-audit/MC-02/postcheck.json
```

Recommended release-note summary line:
- "Malicious-client RLS audit completed: 8/8 scenarios passed; non-admin, anonymous, expired, and direct API bypass write attempts were denied by backend authorization policies."
