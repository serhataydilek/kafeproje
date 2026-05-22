-- Migration: Initialize cafes table if needed and add new columns

CREATE TABLE IF NOT EXISTS public.cafes (
  id TEXT PRIMARY KEY,
  name TEXT,
  district TEXT,
  neighborhood TEXT,
  address TEXT,
  category TEXT,
  rating NUMERIC DEFAULT 0,
  review_count INT DEFAULT 0,
  price_level TEXT,
  description TEXT,
  tags JSONB DEFAULT '[]'::jsonb,
  images JSONB DEFAULT '[]'::jsonb,
  opening_hours JSONB DEFAULT '[]'::jsonb,
  menu_highlights JSONB DEFAULT '[]'::jsonb,
  wifi_quality TEXT,
  outlet_availability TEXT,
  quietness_level TEXT,
  study_friendly BOOLEAN DEFAULT false,
  pet_friendly BOOLEAN DEFAULT false,
  outdoor_seating BOOLEAN DEFAULT false,
  smoking_policy TEXT,
  coordinates JSONB,
  phone_number TEXT,
  website_uri TEXT,
  owner_approval_status TEXT DEFAULT 'approved',
  google_place_id TEXT,
  google_rating NUMERIC,
  google_review_count INT,
  formatted_address TEXT,
  external_last_synced_at TEXT,
  google_has_price_level BOOLEAN DEFAULT false,
  google_uses_app_defaults BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  favorite_count INT DEFAULT 0
);

-- Safely add columns for cases where the table already existed
ALTER TABLE public.cafes ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
ALTER TABLE public.cafes ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.cafes ADD COLUMN IF NOT EXISTS deleted_by UUID;
ALTER TABLE public.cafes ADD COLUMN IF NOT EXISTS favorite_count INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_cafes_is_deleted ON public.cafes (is_deleted);

-- Ensure Fig Coffee & Cocktail exists as an admin-backed canonical venue.
INSERT INTO public.cafes (
  id,
  name,
  district,
  neighborhood,
  address,
  category,
  owner_approval_status,
  is_deleted,
  deleted_at,
  deleted_by,
  tags,
  google_uses_app_defaults
) VALUES (
  'fig-coffee-cocktail-besiktas',
  'Fig Coffee & Cocktail',
  'Besiktas',
  'Visnezade',
  'Suleyman Seba Cd. 85/D, 34357 Besiktas/Istanbul',
  'cafe',
  'approved',
  false,
  null,
  null,
  '["coffee", "cocktail"]'::jsonb,
  false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  district = EXCLUDED.district,
  neighborhood = EXCLUDED.neighborhood,
  address = EXCLUDED.address,
  category = EXCLUDED.category,
  owner_approval_status = 'approved',
  is_deleted = false,
  deleted_at = null,
  deleted_by = null,
  google_uses_app_defaults = false;

-- Resolve hidden/deleted conflicts for the same canonical venue.
UPDATE public.cafes
SET
  is_deleted = false,
  deleted_at = null,
  deleted_by = null,
  owner_approval_status = 'approved'
WHERE LOWER(name) = LOWER('Fig Coffee & Cocktail')
  AND LOWER(district) = LOWER('Besiktas');
