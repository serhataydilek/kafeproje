-- Supabase Migration: Align smoking policy values with the app and enforce
-- one review per user per cafe.

-- Older rows may still use the legacy "mixed" value while the Flutter app
-- submits "outdoor_only". Normalize stored rows before tightening the check.
UPDATE cafe_reviews
SET smoking_policy = 'outdoor_only'
WHERE smoking_policy = 'mixed';

ALTER TABLE cafe_reviews
DROP CONSTRAINT IF EXISTS cafe_reviews_smoking_policy_check;

ALTER TABLE cafe_reviews
ADD CONSTRAINT cafe_reviews_smoking_policy_check
CHECK (
  smoking_policy IS NULL OR
  smoking_policy IN ('allowed', 'outdoor_only', 'not_allowed', 'unknown')
);

-- Keep only the newest review when legacy duplicates exist.
WITH ranked_reviews AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY cafe_id, user_id
      ORDER BY created_at DESC, id DESC
    ) AS row_num
  FROM cafe_reviews
)
DELETE FROM cafe_reviews
WHERE id IN (
  SELECT id
  FROM ranked_reviews
  WHERE row_num > 1
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cafe_reviews_unique_user_cafe
ON cafe_reviews(cafe_id, user_id);
