# RLS Malicious-Client Release Evidence Template

Project: Istanbul Cafe Discovery
Audit date:
Auditor:
Environment:
Supabase project ref:

## Scenario Matrix

| Scenario ID | Actor | Endpoint | Expected | Observed status | Observed error/body summary | Data post-check | Verdict |
|---|---|---|---|---|---|---|---|
| MC-01 | non_admin_user | POST /rest/v1/cafes | Denied | | | No row created | |
| MC-02 | non_admin_user | PATCH /rest/v1/cafes?id=eq.<id> | Denied | | | Row unchanged | |
| MC-03 | non_admin_user | DELETE /rest/v1/cafes?id=eq.<id> | Denied | | | Row still exists | |
| MC-04 | non_admin_user | PATCH is_deleted=true | Denied | | | is_deleted unchanged | |
| MC-05 | anon | POST /rest/v1/cafes | Denied | | | No row created | |
| MC-06 | expired_session | PATCH /rest/v1/cafes?id=eq.<id> | Denied | | | Row unchanged | |
| MC-07 | external direct API | Same as MC-01/02/04 | Denied | | | No unauthorized mutation | |
| MC-08 | anon and non_admin_user | GET /rest/v1/cafes | Allowed read only | | | Reads OK; writes still denied | |

## Evidence Block Template

Scenario:
Actor:
Timestamp UTC:
Endpoint:
Request headers snapshot:
Request payload:
Expected outcome:
Observed status:
Observed response:
Post-check SQL/API evidence:
Verdict:
Artifact files:
- security-evidence/rls-audit/<scenario-id>/request.txt
- security-evidence/rls-audit/<scenario-id>/response.txt
- security-evidence/rls-audit/<scenario-id>/postcheck.json

## Release Signoff Rule

Pass if:
1. MC-01 through MC-07 are denied by backend authorization.
2. MC-08 read behavior matches expected public-read policy.
3. No unauthorized data mutation is observed in post-checks.
