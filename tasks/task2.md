Admin delete still does not work.

Verified Supabase facts:
1. cafes table does NOT have place_id.
2. cafes table has google_place_id.
3. cafes UPDATE policy allows admins if:
   - profiles.role = 'admin'
   OR
   - profiles.is_admin = true
4. Current profiles include:
   - test@gmail.com: role = admin, is_admin = false
   - other users are not admin unless updated

P0 task:
Fix admin delete against the real schema.

Rules:
- Do not use place_id in DB queries. It does not exist.
- Use exact id first.
- Use exact google_place_id second.
- Never use name-only fallback.
- Admin list must exclude is_deleted = true.

Required:
1. Search delete flow for:
   - place_id
   - placeId
   - google_place_id
   - googlePlaceId

2. Fix delete resolution:
   - if cafe.id exists, soft-delete by id
   - else if cafe.googlePlaceId/placeId exists, soft-delete by google_place_id
   - else fail safely with a clear user-safe error
   - never create tombstone/delete by name only

3. Fix app admin check:
   - Treat user as admin if role == 'admin' OR is_admin == true.
   - Do not rely only on is_admin if role exists.
   - Refresh profile/admin state after login or after app restart.

4. Fix Supabase mutation:
   - update public.cafes
   - set is_deleted = true, deleted_at = now(), deleted_by = auth.uid()
   - where id = exact id OR google_place_id = exact google_place_id
   - do not reference place_id

5. Add temporary sanitized delete logs:
   - delete button pressed
   - confirmation accepted
   - current user exists yes/no
   - current user admin role/is_admin check result
   - cafe id present yes/no
   - google_place_id present yes/no
   - delete resolution path
   - Supabase mutation success/failure
   - sanitized error code/message
   - provider invalidated yes/no
   - admin list count after refresh
   - cache/tombstone cleanup yes/no

6. If delete still fails:
   - classify as admin role mismatch, RLS block, wrong id/google_place_id, or UI/cache issue.

Tests:
- Delete uses exact id first.
- Delete uses exact google_place_id second.
- Delete never uses name-only fallback.
- Delete does not query place_id.
- Admin check accepts role = admin even when is_admin = false.
- Admin check accepts is_admin = true.
- Admin list excludes is_deleted = true.
- Deleted cafe does not return from cache/Google merge.

Run:
flutter analyze
flutter test -r compact

Final report:
1. Exact root cause
2. Whether delete was using place_id
3. Whether frontend admin check ignored role
4. Before/after delete resolution
5. Files changed
6. Tests added/updated
7. Validation results