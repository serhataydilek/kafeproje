-- Supabase Migration: Make review text content optional
-- This allows users to drop a rating without being forced to type 5 characters.

ALTER TABLE cafe_reviews 
ALTER COLUMN content DROP NOT NULL;

-- If a check constraint exists enforcing a minimum length, drop it.
-- The default name for such a constraint is usually cafe_reviews_content_check
ALTER TABLE cafe_reviews 
DROP CONSTRAINT IF EXISTS cafe_reviews_content_check;
