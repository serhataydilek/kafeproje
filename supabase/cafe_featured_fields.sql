-- Migration: Add admin-controlled featured cafe metadata for Home sponsorships.

ALTER TABLE public.cafes
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS featured_priority integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS featured_until timestamptz,
  ADD COLUMN IF NOT EXISTS featured_label text;

CREATE INDEX IF NOT EXISTS idx_cafes_featured_home
  ON public.cafes (
    featured_priority DESC,
    featured_until,
    name
  )
  WHERE is_deleted = false
    AND owner_approval_status = 'approved'
    AND is_featured = true;
