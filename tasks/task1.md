We now verified the actual Supabase state.

Facts:
1. public.cafes has active featured rows:
   - 7K coffee workshop
   - Fig Coffee & Cocktail
   - B.BLOK Bakery - Akaretler
2. These rows have:
   - is_featured = true
   - featured_until = NULL
   - is_deleted = false
   - google_place_id exists
3. public.cafes SELECT policy is public true:
   - Cafes are viewable by everyone
4. Therefore featured not showing is not caused by missing featured data or SELECT RLS.
5. The DB does NOT have place_id.
6. The DB uses google_place_id.

P0 task:
Fix Home featured cafes by aligning the app with the real DB schema and finding where the 3 verified rows disappear.

Do not create more migrations for place_id.
Do not fake data.
Do not claim RLS is blocking featured SELECT because policy is SELECT true.

Required:
1. Search all Dart files, tests, SQL, and migrations for:
   - place_id
   - placeId
   - google_place_id
   - googlePlaceId

2. Fix Supabase featured query:
   - It must not select place_id.
   - It must select google_place_id.
   - It must filter:
     is_featured = true
     is_deleted = false or null
     featured_until is null OR featured_until > now()
   - It must order by featured_priority.
   - It must map google_place_id into the Cafe model field.

3. Add temporary sanitized logs for featured flow:
   - Supabase URL host/project ref only
   - featured query started
   - selected columns
   - query success/failure
   - sanitized error code/message if failed
   - row count returned
   - mapped count
   - filtered count
   - cache overwrite yes/no
   - final provider emitted count
   - Home section visible/hidden and reason

4. Find exact disappearance layer:
   - query error
   - query returns 0
   - mapping drops rows
   - classifier drops rows
   - cache overwrites rows
   - Home render condition hides section

5. Fix the exact layer.

Tests:
- Featured query does not request place_id.
- Featured query uses google_place_id.
- google_place_id maps into Cafe model correctly.
- Home renders the 3 verified featured rows from mocked Supabase data.
- Missing place_id does not drop featured rows.
- General discovery classifier does not drop curated featured rows.
- Empty cache cannot overwrite network featured data.

Run:
flutter analyze
flutter test -r compact

Final report:
1. Exact root cause
2. Whether query was requesting place_id
3. Before/after featured query
4. Where the rows disappeared
5. Files changed
6. Tests added/updated
7. Validation results