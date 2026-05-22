-- Migration: Resolve featured/deletion blockers and ensure admin RLS readiness.

-- Core columns required by app queries and mutations.
ALTER TABLE public.cafes
  ADD COLUMN IF NOT EXISTS owner_approval_status TEXT DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID,
  ADD COLUMN IF NOT EXISTS favorite_count INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS featured_priority INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS featured_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS featured_label TEXT;

CREATE INDEX IF NOT EXISTS idx_cafes_is_deleted
  ON public.cafes (is_deleted);

CREATE INDEX IF NOT EXISTS idx_cafes_featured_home
  ON public.cafes (
    featured_priority DESC,
    featured_until,
    name
  )
  WHERE is_deleted = false
    AND owner_approval_status = 'approved'
    AND is_featured = true;

-- RLS policies for public read and admin mutations.
ALTER TABLE public.cafes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cafes are viewable by everyone" ON public.cafes;
CREATE POLICY "Cafes are viewable by everyone"
  ON public.cafes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins can insert cafes" ON public.cafes;
CREATE POLICY "Admins can insert cafes"
  ON public.cafes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM profiles p
      WHERE p.id = auth.uid()
        AND (
          lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
          OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
        )
    )
  );

DROP POLICY IF EXISTS "Admins can update cafes" ON public.cafes;
CREATE POLICY "Admins can update cafes"
  ON public.cafes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM profiles p
      WHERE p.id = auth.uid()
        AND (
          lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
          OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM profiles p
      WHERE p.id = auth.uid()
        AND (
          lower(coalesce(to_jsonb(p) ->> 'role', '')) = 'admin'
          OR lower(coalesce(to_jsonb(p) ->> 'is_admin', '')) IN ('true', 't', '1')
        )
    )
  );

-- Runtime security readiness probe used by the app.
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
