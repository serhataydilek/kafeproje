-- Migration: Targeted cafe query index hardening for release readiness.
--
-- Focus: high-frequency query paths in CafeQueryService:
-- 1) Public discovery and admin status list sorting
-- 2) Place-id overlay/detail lookups
-- 3) Name-search hydration and admin name search
-- 4) District-based discovery/admin filtering with ILIKE

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Supports:
-- - public discovery: is_deleted=false AND owner_approval_status='approved'
--   ORDER BY rating DESC, name ASC
-- - admin visible/deleted status pages with rating/name ordering
CREATE INDEX IF NOT EXISTS idx_cafes_status_rating_name
  ON public.cafes (is_deleted, owner_approval_status, rating DESC, name ASC);

-- Supports:
-- - fetchCafesByPlaceIds(inFilter google_place_id)
-- - fetchCafeById fallback by google_place_id
-- - merge overlay lookups keyed by place id
CREATE INDEX IF NOT EXISTS idx_cafes_google_place_id
  ON public.cafes (google_place_id)
  WHERE google_place_id IS NOT NULL;

-- Supports ILIKE '%...%' name searches used by hydration/admin search.
CREATE INDEX IF NOT EXISTS idx_cafes_name_trgm
  ON public.cafes
  USING gin (name gin_trgm_ops)
  WHERE name IS NOT NULL;

-- Supports ILIKE district filtering in discovery/admin list queries.
CREATE INDEX IF NOT EXISTS idx_cafes_district_trgm
  ON public.cafes
  USING gin (district gin_trgm_ops)
  WHERE district IS NOT NULL;
