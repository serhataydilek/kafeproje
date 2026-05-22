-- Runtime security readiness probe for app startup checks.
-- This function is intentionally SECURITY DEFINER so anon/authenticated clients
-- can verify whether critical RLS policies are in place.

CREATE OR REPLACE FUNCTION public.app_security_readiness()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
WITH cafe_table AS (
  SELECT c.relrowsecurity AS rls_enabled
  FROM pg_class c
  INNER JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'cafes'
  LIMIT 1
), policy_flags AS (
  SELECT
    EXISTS (
      SELECT 1
      FROM pg_policies p
      WHERE p.schemaname = 'public'
        AND p.tablename = 'cafes'
        AND lower(p.cmd) = 'insert'
        AND lower(COALESCE(p.with_check, '')) LIKE '%profiles%'
        AND lower(COALESCE(p.with_check, '')) LIKE '%auth.uid%'
        AND (
          lower(COALESCE(p.with_check, '')) LIKE '%admin%'
          OR lower(COALESCE(p.with_check, '')) LIKE '%is_admin%'
        )
    ) AS has_admin_insert_policy,
    EXISTS (
      SELECT 1
      FROM pg_policies p
      WHERE p.schemaname = 'public'
        AND p.tablename = 'cafes'
        AND lower(p.cmd) = 'update'
        AND lower(COALESCE(p.qual, '')) LIKE '%profiles%'
        AND lower(COALESCE(p.qual, '')) LIKE '%auth.uid%'
        AND lower(COALESCE(p.with_check, '')) LIKE '%profiles%'
        AND lower(COALESCE(p.with_check, '')) LIKE '%auth.uid%'
        AND (
          lower(COALESCE(p.qual, '')) LIKE '%admin%'
          OR lower(COALESCE(p.qual, '')) LIKE '%is_admin%'
        )
        AND (
          lower(COALESCE(p.with_check, '')) LIKE '%admin%'
          OR lower(COALESCE(p.with_check, '')) LIKE '%is_admin%'
        )
    ) AS has_admin_update_policy
)
SELECT jsonb_build_object(
  'is_ready',
    COALESCE((SELECT rls_enabled FROM cafe_table), false)
    AND (SELECT has_admin_insert_policy FROM policy_flags)
    AND (SELECT has_admin_update_policy FROM policy_flags),
  'rls_enabled', COALESCE((SELECT rls_enabled FROM cafe_table), false),
  'has_admin_insert_policy', (SELECT has_admin_insert_policy FROM policy_flags),
  'has_admin_update_policy', (SELECT has_admin_update_policy FROM policy_flags),
  'message',
    CASE
      WHEN COALESCE((SELECT rls_enabled FROM cafe_table), false)
        AND (SELECT has_admin_insert_policy FROM policy_flags)
        AND (SELECT has_admin_update_policy FROM policy_flags)
        THEN 'Security readiness check passed.'
      ELSE 'Missing required cafes RLS setup. Ensure RLS is enabled and admin insert/update policies exist.'
    END
);
$$;

GRANT EXECUTE ON FUNCTION public.app_security_readiness() TO anon;
GRANT EXECUTE ON FUNCTION public.app_security_readiness() TO authenticated;
